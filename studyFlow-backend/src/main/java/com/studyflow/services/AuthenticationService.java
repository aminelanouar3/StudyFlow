
package com.studyflow.services;

import com.studyflow.dto.AuthResponse;
import com.studyflow.util.DatabaseConnection;

import javax.ejb.Stateless;
import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebService;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import org.mindrot.jbcrypt.BCrypt;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Base64;
import java.sql.Timestamp;


@Stateless
@WebService(
        serviceName = "AuthenticationService",
        targetNamespace = "http://services.studyflow.com/"
)
public class AuthenticationService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private static final String EMAIL_VERIFICATION = "EMAIL_VERIFICATION";
    private static final String PASSWORD_RESET = "PASSWORD_RESET";
    private static final String EMAIL_CHANGE = "EMAIL_CHANGE";

    private static final int CODE_VALIDITY_MINUTES = 5;
    private static final int MAX_ATTEMPTS = 5;
    private static final int RESEND_DELAY_SECONDS = 60;

    // REGISTER
    @WebMethod
    public AuthResponse register(
            @WebParam(name = "fullName") String fullName,
            @WebParam(name = "email") String email,
            @WebParam(name = "password") String password) {

        if (fullName == null || fullName.trim().isEmpty()
                || email == null || email.trim().isEmpty()
                || password == null || password.length() < 8) {

            return new AuthResponse(false,
                    "Please provide valid information. Password must contain at least 8 characters.");
        }

        String normalizedEmail = email.trim().toLowerCase();
        String code = generateVerificationCode();

        String sql = "INSERT INTO users "
                + "(full_name, email, password, email_verified) "
                + "VALUES (?, ?, ?, 0)";

        int userId;

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement statement = connection.prepareStatement(
                     sql, Statement.RETURN_GENERATED_KEYS)) {

            String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt(12));

            statement.setString(1, fullName.trim());
            statement.setString(2, normalizedEmail);
            statement.setString(3, hashedPassword);

            statement.executeUpdate();

            try (ResultSet keys = statement.getGeneratedKeys()) {
                if (!keys.next()) {
                    return new AuthResponse(false, "Unable to create account.");
                }

                userId = keys.getInt(1);
            }

            saveVerificationCode(connection, userId, code, EMAIL_VERIFICATION);

        } catch (SQLException e) {

            if ("23000".equals(e.getSQLState())) {
                return new AuthResponse(false,
                        "An account with this email already exists.");
            }

            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }

        try {
            EmailService.sendVerificationCode(
                    normalizedEmail, code, EMAIL_VERIFICATION);

            return new AuthResponse(true,
                    "Account created. A verification code has been sent to your email.");

        } catch (Exception e) {
            e.printStackTrace();

            return new AuthResponse(false,
                    "Account created, but the verification email could not be sent. Please try again later.");
        }
    }

    // VERIFY EMAIL
    @WebMethod
    public AuthResponse verifyEmail(
            @WebParam(name = "email") String email,
            @WebParam(name = "code") String code) {

        if (email == null || email.trim().isEmpty()
                || code == null || !code.matches("\\d{6}")) {

            return new AuthResponse(false,
                    "A valid email and six-digit code are required.");
        }

        String normalizedEmail = email.trim().toLowerCase();

        String selectUser =
                "SELECT id, email_verified FROM users WHERE email = ?";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement userStatement =
                     connection.prepareStatement(selectUser)) {

            userStatement.setString(1, normalizedEmail);

            try (ResultSet userResult = userStatement.executeQuery()) {

                if (!userResult.next()) {
                    return new AuthResponse(false, "Invalid verification request.");
                }

                int userId = userResult.getInt("id");

                if (userResult.getBoolean("email_verified")) {
                    return new AuthResponse(true,
                            "Email address is already verified.");
                }

                connection.setAutoCommit(false);

                try {
                    String selectCode =
                            "SELECT id, code_hash, attempts "
                                    + "FROM verification_codes "
                                    + "WHERE user_id = ? "
                                    + "AND purpose = ? "
                                    + "AND expires_at > NOW() "
                                    + "AND attempts < ? "
                                    + "ORDER BY id DESC LIMIT 1 FOR UPDATE";

                    int verificationId;
                    String storedHash;

                    try (PreparedStatement codeStatement =
                                 connection.prepareStatement(selectCode)) {

                        codeStatement.setInt(1, userId);
                        codeStatement.setString(2, EMAIL_VERIFICATION);
                        codeStatement.setInt(3, MAX_ATTEMPTS);

                        try (ResultSet codeResult = codeStatement.executeQuery()) {

                            if (!codeResult.next()) {
                                connection.rollback();
                                return new AuthResponse(false,
                                        "Verification code expired or invalid. Request a new code.");
                            }

                            verificationId = codeResult.getInt("id");
                            storedHash = codeResult.getString("code_hash");
                        }
                    }

                    if (!BCrypt.checkpw(code, storedHash)) {

                        String updateAttempts =
                                "UPDATE verification_codes "
                                        + "SET attempts = attempts + 1 WHERE id = ?";

                        try (PreparedStatement attemptStatement =
                                     connection.prepareStatement(updateAttempts)) {

                            attemptStatement.setInt(1, verificationId);
                            attemptStatement.executeUpdate();
                        }

                        connection.commit();

                        return new AuthResponse(false,
                                "Incorrect verification code.");
                    }

                    String activateUser =
                            "UPDATE users SET email_verified = 1 WHERE id = ?";

                    try (PreparedStatement activateStatement =
                                 connection.prepareStatement(activateUser)) {

                        activateStatement.setInt(1, userId);
                        activateStatement.executeUpdate();
                    }

                    deleteVerificationCodes(connection, userId, EMAIL_VERIFICATION);

                    connection.commit();

                    return new AuthResponse(true,
                            "Email verified successfully. You can now log in.");

                } catch (Exception e) {
                    connection.rollback();
                    throw e;
                } finally {
                    connection.setAutoCommit(true);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    // RESEND EMAIL VERIFICATION CODE
    @WebMethod
    public AuthResponse resendVerificationCode(
            @WebParam(name = "email") String email) {

        if (email == null || email.trim().isEmpty()) {
            return new AuthResponse(false, "Email is required.");
        }

        String normalizedEmail = email.trim().toLowerCase();

        String selectUser =
                "SELECT id, email_verified FROM users WHERE email = ?";

        String code = generateVerificationCode();

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement userStatement =
                     connection.prepareStatement(selectUser)) {

            userStatement.setString(1, normalizedEmail);

            try (ResultSet userResult = userStatement.executeQuery()) {

                if (!userResult.next()) {
                    return new AuthResponse(false,
                            "No account found with this email.");
                }

                int userId = userResult.getInt("id");

                if (userResult.getBoolean("email_verified")) {
                    return new AuthResponse(false,
                            "This email address is already verified.");
                }

                String cooldownSql =
                        "SELECT COUNT(*) FROM verification_codes "
                                + "WHERE user_id = ? AND purpose = ? "
                                + "AND created_at > DATE_SUB(NOW(), INTERVAL "
                                + RESEND_DELAY_SECONDS + " SECOND)";

                try (PreparedStatement cooldownStatement =
                             connection.prepareStatement(cooldownSql)) {

                    cooldownStatement.setInt(1, userId);
                    cooldownStatement.setString(2, EMAIL_VERIFICATION);

                    try (ResultSet cooldownResult =
                                 cooldownStatement.executeQuery()) {

                        if (cooldownResult.next()
                                && cooldownResult.getInt(1) > 0) {

                            return new AuthResponse(false,
                                    "Please wait 60 seconds before requesting another code.");
                        }
                    }
                }

                saveVerificationCode(
                        connection, userId, code, EMAIL_VERIFICATION);
            }

            try {
                EmailService.sendVerificationCode(
                        normalizedEmail, code, EMAIL_VERIFICATION);

                return new AuthResponse(true,
                        "A new verification code has been sent.");

            } catch (Exception e) {
                e.printStackTrace();

                return new AuthResponse(false,
                        "Unable to send verification email.");
            }

        } catch (SQLException e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    // FORGOT PASSWORD
    @WebMethod
    public AuthResponse forgotPassword(
            @WebParam(name = "email") String email) {

        if (email == null || email.trim().isEmpty()) {
            return new AuthResponse(false, "Email is required.");
        }

        String normalizedEmail = email.trim().toLowerCase();

        String sql =
                "SELECT id FROM users "
                        + "WHERE email = ? AND email_verified = 1";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {

            statement.setString(1, normalizedEmail);

            try (ResultSet result = statement.executeQuery()) {

                if (!result.next()) {
                    return new AuthResponse(true,
                            "If an account exists with this email, a reset code will be sent.");
                }

                int userId = result.getInt("id");

                String cooldownSql =
                        "SELECT COUNT(*) FROM verification_codes "
                                + "WHERE user_id = ? AND purpose = ? "
                                + "AND created_at > DATE_SUB(NOW(), INTERVAL "
                                + RESEND_DELAY_SECONDS + " SECOND)";

                try (PreparedStatement cooldownStatement =
                             connection.prepareStatement(cooldownSql)) {

                    cooldownStatement.setInt(1, userId);
                    cooldownStatement.setString(2, PASSWORD_RESET);

                    try (ResultSet cooldownResult =
                                 cooldownStatement.executeQuery()) {

                        if (cooldownResult.next()
                                && cooldownResult.getInt(1) > 0) {

                            return new AuthResponse(true,
                                    "If an account exists with this email, a reset code will be sent.");
                        }
                    }
                }

                String code = generateVerificationCode();

                saveVerificationCode(
                        connection, userId, code, PASSWORD_RESET);

                try {
                    EmailService.sendVerificationCode(
                            normalizedEmail, code, PASSWORD_RESET);

                } catch (Exception e) {
                    e.printStackTrace();
                }

                return new AuthResponse(true,
                        "If an account exists with this email, a reset code will be sent.");
            }

        } catch (SQLException e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    // VERIFY PASSWORD RESET CODE
    @WebMethod
    public AuthResponse verifyResetCode(
            @WebParam(name = "email") String email,
            @WebParam(name = "code") String code) {

        if (email == null || email.trim().isEmpty()
                || code == null || !code.matches("\\d{6}")) {

            return new AuthResponse(false,
                    "A valid email and six-digit code are required.");
        }

        String normalizedEmail = email.trim().toLowerCase();

        String userSql =
                "SELECT id FROM users "
                        + "WHERE email = ? AND email_verified = 1";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement userStatement =
                     connection.prepareStatement(userSql)) {

            userStatement.setString(1, normalizedEmail);

            try (ResultSet userResult = userStatement.executeQuery()) {

                if (!userResult.next()) {
                    return new AuthResponse(false,
                            "Invalid or expired reset code.");
                }

                int userId = userResult.getInt("id");

                connection.setAutoCommit(false);

                try {
                    String codeSql =
                            "SELECT id, code_hash FROM verification_codes "
                                    + "WHERE user_id = ? "
                                    + "AND purpose = ? "
                                    + "AND expires_at > NOW() "
                                    + "AND attempts < ? "
                                    + "ORDER BY id DESC LIMIT 1 FOR UPDATE";

                    int codeId;
                    String storedHash;

                    try (PreparedStatement codeStatement =
                                 connection.prepareStatement(codeSql)) {

                        codeStatement.setInt(1, userId);
                        codeStatement.setString(2, PASSWORD_RESET);
                        codeStatement.setInt(3, MAX_ATTEMPTS);

                        try (ResultSet codeResult = codeStatement.executeQuery()) {

                            if (!codeResult.next()) {
                                connection.rollback();
                                return new AuthResponse(false,
                                        "Invalid or expired reset code.");
                            }

                            codeId = codeResult.getInt("id");
                            storedHash = codeResult.getString("code_hash");
                        }
                    }

                    if (!BCrypt.checkpw(code, storedHash)) {

                        String updateSql =
                                "UPDATE verification_codes "
                                        + "SET attempts = attempts + 1 "
                                        + "WHERE id = ?";

                        try (PreparedStatement updateStatement =
                                     connection.prepareStatement(updateSql)) {

                            updateStatement.setInt(1, codeId);
                            updateStatement.executeUpdate();
                        }

                        connection.commit();

                        return new AuthResponse(false,
                                "Incorrect reset code.");
                    }

                    connection.commit();

                    return new AuthResponse(true,
                            "Reset code verified successfully.");

                } catch (Exception e) {
                    connection.rollback();
                    throw e;
                } finally {
                    connection.setAutoCommit(true);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    // RESET PASSWORD
    @WebMethod
    public AuthResponse resetPassword(
            @WebParam(name = "email") String email,
            @WebParam(name = "code") String code,
            @WebParam(name = "newPassword") String newPassword) {

        if (email == null || email.trim().isEmpty()
                || code == null || !code.matches("\\d{6}")
                || newPassword == null || newPassword.length() < 8) {

            return new AuthResponse(false,
                    "Valid email, six-digit code and a password of at least 8 characters are required.");
        }

        String normalizedEmail = email.trim().toLowerCase();

        String userSql =
                "SELECT id FROM users "
                        + "WHERE email = ? AND email_verified = 1";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement userStatement =
                     connection.prepareStatement(userSql)) {

            userStatement.setString(1, normalizedEmail);

            try (ResultSet userResult = userStatement.executeQuery()) {

                if (!userResult.next()) {
                    return new AuthResponse(false,
                            "Invalid or expired reset code.");
                }

                int userId = userResult.getInt("id");

                connection.setAutoCommit(false);

                try {
                    String codeSql =
                            "SELECT id, code_hash FROM verification_codes "
                                    + "WHERE user_id = ? "
                                    + "AND purpose = ? "
                                    + "AND expires_at > NOW() "
                                    + "AND attempts < ? "
                                    + "ORDER BY id DESC LIMIT 1 FOR UPDATE";

                    int codeId;
                    String storedHash;

                    try (PreparedStatement codeStatement =
                                 connection.prepareStatement(codeSql)) {

                        codeStatement.setInt(1, userId);
                        codeStatement.setString(2, PASSWORD_RESET);
                        codeStatement.setInt(3, MAX_ATTEMPTS);

                        try (ResultSet codeResult = codeStatement.executeQuery()) {

                            if (!codeResult.next()) {
                                connection.rollback();
                                return new AuthResponse(false,
                                        "Invalid or expired reset code.");
                            }

                            codeId = codeResult.getInt("id");
                            storedHash = codeResult.getString("code_hash");
                        }
                    }

                    if (!BCrypt.checkpw(code, storedHash)) {

                        String updateAttempts =
                                "UPDATE verification_codes "
                                        + "SET attempts = attempts + 1 "
                                        + "WHERE id = ?";

                        try (PreparedStatement attemptStatement =
                                     connection.prepareStatement(updateAttempts)) {

                            attemptStatement.setInt(1, codeId);
                            attemptStatement.executeUpdate();
                        }

                        connection.commit();

                        return new AuthResponse(false,
                                "Incorrect reset code.");
                    }

                    String hashedPassword =
                            BCrypt.hashpw(newPassword, BCrypt.gensalt(12));

                    String updatePassword =
                            "UPDATE users SET password = ? WHERE id = ?";

                    try (PreparedStatement passwordStatement =
                                 connection.prepareStatement(updatePassword)) {

                        passwordStatement.setString(1, hashedPassword);
                        passwordStatement.setInt(2, userId);
                        passwordStatement.executeUpdate();
                    }

                    // Delete the used reset code.
                    deleteVerificationCodes(
                            connection, userId, PASSWORD_RESET);

                    // Invalidate all existing sessions for this user.
                    String deleteSessions =
                            "DELETE FROM user_tokens WHERE user_id = ?";

                    try (PreparedStatement sessionStatement =
                                 connection.prepareStatement(deleteSessions)) {

                        sessionStatement.setInt(1, userId);
                        sessionStatement.executeUpdate();
                    }

                    connection.commit();

                    return new AuthResponse(true,
                            "Password reset successfully. Please log in with your new password.");

                } catch (Exception e) {
                    connection.rollback();
                    throw e;
                } finally {
                    connection.setAutoCommit(true);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    // LOGIN
    @WebMethod
    public AuthResponse login(
            @WebParam(name = "email") String email,
            @WebParam(name = "password") String password) {

        if (email == null || password == null
                || email.trim().isEmpty() || password.isEmpty()) {

            return new AuthResponse(false,
                    "Email and password are required.");
        }

        String sql =
                "SELECT id, full_name, email, password, email_verified "
                        + "FROM users WHERE email = ?";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {

            statement.setString(1, email.trim().toLowerCase());

            try (ResultSet result = statement.executeQuery()) {

                if (!result.next()) {
                    return new AuthResponse(false,
                            "Invalid email or password.");
                }

                String storedPassword = result.getString("password");

                if (!BCrypt.checkpw(password, storedPassword)) {
                    return new AuthResponse(false,
                            "Invalid email or password.");
                }

                if (!result.getBoolean("email_verified")) {
                    return new AuthResponse(false,
                            "Please verify your email address before logging in.");
                }

                int userId = result.getInt("id");
                String fullName = result.getString("full_name");
                String userEmail = result.getString("email");

                String token = generateToken();

                String insertToken =
                        "INSERT INTO user_tokens (user_id, token) VALUES (?, ?)";

                try (PreparedStatement tokenStatement =
                             connection.prepareStatement(insertToken)) {

                    tokenStatement.setInt(1, userId);
                    tokenStatement.setString(2, hashToken(token));
                    tokenStatement.executeUpdate();
                }

                AuthResponse response =
                        new AuthResponse(true, "Login successful.");

                response.setToken(token);
                response.setUserId(userId);
                response.setFullName(fullName);
                response.setEmail(userEmail);

                return response;
            }

        } catch (SQLException e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    // LOGOUT
    @WebMethod
    public AuthResponse logout(
            @WebParam(name = "token") String token) {

        if (token == null || token.trim().isEmpty()) {
            return new AuthResponse(false, "Token is required.");
        }

        String sql = "DELETE FROM user_tokens WHERE token = ?";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {

            statement.setString(1, hashToken(token));

            int deleted = statement.executeUpdate();

            if (deleted == 0) {
                return new AuthResponse(false, "Invalid session.");
            }

            return new AuthResponse(true, "Logout successful.");

        } catch (SQLException e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    // GET PROFILE
    @WebMethod
    public AuthResponse getProfile(
            @WebParam(name = "token") String token) {

        if (token == null || token.trim().isEmpty()) {
            return new AuthResponse(false, "Token is required.");
        }

        String sql =
                "SELECT u.id, u.full_name, u.email "
                        + "FROM users u "
                        + "INNER JOIN user_tokens t ON u.id = t.user_id "
                        + "WHERE t.token = ?";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {

            statement.setString(1, hashToken(token));

            try (ResultSet result = statement.executeQuery()) {

                if (!result.next()) {
                    return new AuthResponse(false,
                            "Invalid session. Please log in again.");
                }

                AuthResponse response =
                        new AuthResponse(true, "Profile retrieved successfully.");

                response.setUserId(result.getInt("id"));
                response.setFullName(result.getString("full_name"));
                response.setEmail(result.getString("email"));

                return response;
            }

        } catch (SQLException e) {
            e.printStackTrace();
            return new AuthResponse(false, "Database error.");
        }
    }

    @WebMethod(operationName = "changePassword")
    public AuthResponse changePassword(
            @WebParam(name = "token") String token,
            @WebParam(name = "currentPassword") String currentPassword,
            @WebParam(name = "newPassword") String newPassword) {

        if (token == null || token.trim().isEmpty()) {
            return new AuthResponse(false, "Invalid session token.");
        }

        if (currentPassword == null || currentPassword.isEmpty()) {
            return new AuthResponse(false, "Current password is required.");
        }

        if (newPassword == null || newPassword.length() < 8) {
            return new AuthResponse(false,
                    "New password must contain at least 8 characters.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId;
            String storedPassword;

            // Verify session and retrieve current password hash
            String selectSql =
                    "SELECT u.id, u.password " +
                            "FROM users u " +
                            "INNER JOIN user_tokens t ON u.id = t.user_id " +
                            "WHERE t.token = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(selectSql)) {

                statement.setString(1, hashToken(token));

                try (ResultSet result = statement.executeQuery()) {

                    if (!result.next()) {
                        return new AuthResponse(false,
                                "Invalid or expired session.");
                    }

                    userId = result.getInt("id");
                    storedPassword = result.getString("password");
                }
            }

            // Verify current password
            if (!BCrypt.checkpw(currentPassword, storedPassword)) {
                return new AuthResponse(false,
                        "Current password is incorrect.");
            }

            // Prevent reusing the current password
            if (BCrypt.checkpw(newPassword, storedPassword)) {
                return new AuthResponse(false,
                        "New password must be different from current password.");
            }

            // Hash the new password
            String newPasswordHash = BCrypt.hashpw(
                    newPassword,
                    BCrypt.gensalt()
            );

            // Update password without invalidating existing sessions
            String updateSql =
                    "UPDATE users SET password = ? WHERE id = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(updateSql)) {

                statement.setString(1, newPasswordHash);
                statement.setInt(2, userId);

                int updatedRows = statement.executeUpdate();

                if (updatedRows != 1) {
                    return new AuthResponse(false,
                            "Failed to update password.");
                }
            }

            return new AuthResponse(true,
                    "Password changed successfully.");

        } catch (Exception e) {
            e.printStackTrace();

            return new AuthResponse(false,
                    "An error occurred while changing password.");
        }
    }

    @WebMethod(operationName = "changeFullName")
    public AuthResponse changeFullName(
            @WebParam(name = "token") String token,
            @WebParam(name = "currentPassword") String currentPassword,
            @WebParam(name = "newFullName") String newFullName) {

        if (token == null || token.trim().isEmpty()) {
            return new AuthResponse(false, "Authentication token is required.");
        }

        if (currentPassword == null || currentPassword.isEmpty()) {
            return new AuthResponse(false, "Current password is required.");
        }

        if (newFullName == null || newFullName.trim().isEmpty()) {
            return new AuthResponse(false, "New name is required.");
        }

        newFullName = newFullName.trim();

        try (Connection connection = DatabaseConnection.getConnection()) {

            String selectSql =
                    "SELECT u.id, u.password, u.email, u.full_name " +
                            "FROM users u " +
                            "INNER JOIN user_tokens t ON u.id = t.user_id " +
                            "WHERE t.token = ?";

            int userId;
            String storedPassword;
            String currentFullName;
            String email;

            try (PreparedStatement statement =
                         connection.prepareStatement(selectSql)) {

                statement.setString(1, hashToken(token));

                try (ResultSet result = statement.executeQuery()) {

                    if (!result.next()) {
                        return new AuthResponse(false, "Invalid or expired session.");
                    }

                    userId = result.getInt("id");
                    storedPassword = result.getString("password");
                    email = result.getString("email");
                    currentFullName = result.getString("full_name");
                }
            }

            if (!BCrypt.checkpw(currentPassword, storedPassword)) {
                return new AuthResponse(false, "Incorrect current password.");
            }

            if (newFullName.equals(currentFullName)) {
                return new AuthResponse(false, "The new name is identical to the current name.");
            }

            String updateSql =
                    "UPDATE users SET full_name = ? WHERE id = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(updateSql)) {

                statement.setString(1, newFullName);
                statement.setInt(2, userId);

                int updatedRows = statement.executeUpdate();

                if (updatedRows == 0) {
                    return new AuthResponse(false, "Name update failed.");
                }
            }

            AuthResponse response =
                    new AuthResponse(true, "Name updated successfully.");

            response.setUserId(userId);
            response.setFullName(newFullName);
            response.setEmail(email);

            return response;

        } catch (Exception e) {
            e.printStackTrace();
            return new AuthResponse(false, "Unable to update name.");
        }
    }


    @WebMethod(operationName = "requestEmailChange")
    public AuthResponse requestEmailChange(
            @WebParam(name = "token") String token,
            @WebParam(name = "currentPassword") String currentPassword,
            @WebParam(name = "newEmail") String newEmail) {

        if (token == null || token.trim().isEmpty()) {
            return new AuthResponse(false, "Invalid session token.");
        }

        if (currentPassword == null || currentPassword.isEmpty()) {
            return new AuthResponse(false, "Current password is required.");
        }

        if (newEmail == null || !newEmail.trim().matches(
                "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")) {
            return new AuthResponse(false, "Invalid email address.");
        }

        newEmail = newEmail.trim();

        int userId;
        String oldEmail;
        String storedPassword;
        String code = generateVerificationCode();

        try (Connection connection = DatabaseConnection.getConnection()) {

            // Authenticate the user using the session token
            String selectSql =
                    "SELECT u.id, u.email, u.password " +
                            "FROM users u " +
                            "INNER JOIN user_tokens t ON u.id = t.user_id " +
                            "WHERE t.token = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(selectSql)) {

                statement.setString(1, hashToken(token));

                try (ResultSet result = statement.executeQuery()) {
                    if (!result.next()) {
                        return new AuthResponse(false,
                                "Invalid or expired session.");
                    }

                    userId = result.getInt("id");
                    oldEmail = result.getString("email");
                    storedPassword = result.getString("password");
                }
            }

            // Require the current password
            if (!BCrypt.checkpw(currentPassword, storedPassword)) {
                return new AuthResponse(false,
                        "Current password is incorrect.");
            }

            if (oldEmail.equalsIgnoreCase(newEmail)) {
                return new AuthResponse(false,
                        "The new email is the same as your current email.");
            }

            // Check whether the new email is already used
            String duplicateSql =
                    "SELECT id FROM users WHERE LOWER(email) = LOWER(?)";

            try (PreparedStatement statement =
                         connection.prepareStatement(duplicateSql)) {

                statement.setString(1, newEmail);

                try (ResultSet result = statement.executeQuery()) {
                    if (result.next()) {
                        return new AuthResponse(false,
                                "This email address is already in use.");
                    }
                }
            }

            // Apply the existing 60-second resend cooldown
            String cooldownSql =
                    "SELECT COUNT(*) FROM verification_codes " +
                            "WHERE user_id = ? AND purpose = ? " +
                            "AND created_at >= DATE_SUB(NOW(), INTERVAL 60 SECOND)";

            try (PreparedStatement statement =
                         connection.prepareStatement(cooldownSql)) {

                statement.setInt(1, userId);
                statement.setString(2, EMAIL_CHANGE);

                try (ResultSet result = statement.executeQuery()) {
                    if (result.next() && result.getInt(1) > 0) {
                        return new AuthResponse(false,
                                "Please wait before requesting another code.");
                    }
                }
            }

            // Remove previous email-change codes
            String deleteSql =
                    "DELETE FROM verification_codes " +
                            "WHERE user_id = ? AND purpose = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(deleteSql)) {

                statement.setInt(1, userId);
                statement.setString(2, EMAIL_CHANGE);
                statement.executeUpdate();
            }

            // Save the hashed code and pending email
            String insertSql =
                    "INSERT INTO verification_codes " +
                            "(user_id, code_hash, purpose, pending_email, " +
                            "expires_at, attempts, created_at) " +
                            "VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 5 MINUTE), 0, NOW())";

            try (PreparedStatement statement =
                         connection.prepareStatement(insertSql)) {

                statement.setInt(1, userId);
                statement.setString(2,
                        BCrypt.hashpw(code, BCrypt.gensalt()));
                statement.setString(3, EMAIL_CHANGE);
                statement.setString(4, newEmail);
                statement.executeUpdate();
            }

        } catch (Exception e) {
            e.printStackTrace();
            return new AuthResponse(false,
                    "Unable to request email change.");
        }

        // Send the code to the NEW email address
        try {
            EmailService.sendVerificationCode(
                    newEmail, code, EMAIL_CHANGE);

            return new AuthResponse(true,
                    "Verification code sent to your new email address.");

        } catch (Exception e) {
            e.printStackTrace();

            // Delete the unusable code if email delivery fails
            try (Connection connection = DatabaseConnection.getConnection();
                 PreparedStatement statement = connection.prepareStatement(
                         "DELETE FROM verification_codes " +
                                 "WHERE user_id = ? AND purpose = ?")) {

                statement.setInt(1, userId);
                statement.setString(2, EMAIL_CHANGE);
                statement.executeUpdate();

            } catch (Exception cleanupError) {
                cleanupError.printStackTrace();
            }

            return new AuthResponse(false,
                    "Unable to send the verification email.");
        }
    }

    @WebMethod(operationName = "verifyEmailChange")
    public AuthResponse verifyEmailChange(
            @WebParam(name = "token") String token,
            @WebParam(name = "code") String code) {

        if (token == null || token.trim().isEmpty()) {
            return new AuthResponse(false, "Invalid session token.");
        }

        if (code == null || !code.trim().matches("\\d{6}")) {
            return new AuthResponse(false, "Invalid verification code.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            connection.setAutoCommit(false);

            try {
                int userId;

                // Authenticate the user
                String userSql =
                        "SELECT u.id FROM users u " +
                                "INNER JOIN user_tokens t ON u.id = t.user_id " +
                                "WHERE t.token = ?";

                try (PreparedStatement statement =
                             connection.prepareStatement(userSql)) {

                    statement.setString(1, hashToken(token));

                    try (ResultSet result = statement.executeQuery()) {
                        if (!result.next()) {
                            connection.rollback();
                            return new AuthResponse(false,
                                    "Invalid or expired session.");
                        }

                        userId = result.getInt("id");
                    }
                }

                // Retrieve the pending email-change code
                String codeSql =
                        "SELECT id, code_hash, pending_email, expires_at, attempts " +
                                "FROM verification_codes " +
                                "WHERE user_id = ? AND purpose = ? " +
                                "ORDER BY created_at DESC LIMIT 1 FOR UPDATE";

                int codeId;
                String codeHash;
                String pendingEmail;
                Timestamp expiresAt;
                int attempts;

                try (PreparedStatement statement =
                             connection.prepareStatement(codeSql)) {

                    statement.setInt(1, userId);
                    statement.setString(2, EMAIL_CHANGE);

                    try (ResultSet result = statement.executeQuery()) {
                        if (!result.next()) {
                            connection.rollback();
                            return new AuthResponse(false,
                                    "No pending email change was found.");
                        }

                        codeId = result.getInt("id");
                        codeHash = result.getString("code_hash");
                        pendingEmail = result.getString("pending_email");
                        expiresAt = result.getTimestamp("expires_at");
                        attempts = result.getInt("attempts");
                    }
                }

                if (attempts >= MAX_ATTEMPTS) {
                    deleteEmailChangeCode(connection, codeId);
                    connection.commit();

                    return new AuthResponse(false,
                            "Maximum verification attempts reached. Request a new code.");
                }

                if (expiresAt == null ||
                        expiresAt.before(new Timestamp(System.currentTimeMillis()))) {

                    deleteEmailChangeCode(connection, codeId);
                    connection.commit();

                    return new AuthResponse(false,
                            "Verification code has expired. Request a new one.");
                }

                // Check the submitted code
                if (!BCrypt.checkpw(code.trim(), codeHash)) {

                    try (PreparedStatement statement =
                                 connection.prepareStatement(
                                         "UPDATE verification_codes " +
                                                 "SET attempts = attempts + 1 WHERE id = ?")) {

                        statement.setInt(1, codeId);
                        statement.executeUpdate();
                    }

                    connection.commit();

                    return new AuthResponse(false,
                            "Incorrect verification code.");
                }

                // Check again that the pending email is still available
                String duplicateSql =
                        "SELECT id FROM users " +
                                "WHERE LOWER(email) = LOWER(?) AND id <> ?";

                try (PreparedStatement statement =
                             connection.prepareStatement(duplicateSql)) {

                    statement.setString(1, pendingEmail);
                    statement.setInt(2, userId);

                    try (ResultSet result = statement.executeQuery()) {
                        if (result.next()) {
                            deleteEmailChangeCode(connection, codeId);
                            connection.commit();

                            return new AuthResponse(false,
                                    "This email address is already in use.");
                        }
                    }
                }

                // Update email ONLY after successful verification
                String updateSql =
                        "UPDATE users SET email = ?, email_verified = 1 " +
                                "WHERE id = ?";

                try (PreparedStatement statement =
                             connection.prepareStatement(updateSql)) {

                    statement.setString(1, pendingEmail);
                    statement.setInt(2, userId);
                    statement.executeUpdate();
                }

                // Remove the used verification code
                deleteEmailChangeCode(connection, codeId);

                connection.commit();

                return new AuthResponse(true,
                        "Email address changed and verified successfully.");

            } catch (Exception e) {
                connection.rollback();
                throw e;
            } finally {
                connection.setAutoCommit(true);
            }

        } catch (Exception e) {
            e.printStackTrace();
            return new AuthResponse(false,
                    "An error occurred while verifying the new email.");
        }
    }

    private void deleteEmailChangeCode(
            Connection connection, int codeId) throws Exception {

        String sql = "DELETE FROM verification_codes WHERE id = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setInt(1, codeId);
            statement.executeUpdate();
        }
    }


    // SAVE A NEW VERIFICATION CODE
    private void saveVerificationCode(
            Connection connection,
            int userId,
            String code,
            String purpose) throws SQLException {

        String deleteSql =
                "DELETE FROM verification_codes WHERE user_id = ? AND purpose = ?";

        try (PreparedStatement deleteStatement =
                     connection.prepareStatement(deleteSql)) {

            deleteStatement.setInt(1, userId);
            deleteStatement.setString(2, purpose);
            deleteStatement.executeUpdate();
        }

        String insertSql =
                "INSERT INTO verification_codes "
                        + "(user_id, code_hash, purpose, expires_at, attempts) "
                        + "VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL "
                        + CODE_VALIDITY_MINUTES + " MINUTE), 0)";

        try (PreparedStatement insertStatement =
                     connection.prepareStatement(insertSql)) {

            insertStatement.setInt(1, userId);
            insertStatement.setString(2,
                    BCrypt.hashpw(code, BCrypt.gensalt(10)));
            insertStatement.setString(3, purpose);

            insertStatement.executeUpdate();
        }
    }

    // DELETE USED CODES
    private void deleteVerificationCodes(
            Connection connection,
            int userId,
            String purpose) throws SQLException {

        String sql =
                "DELETE FROM verification_codes WHERE user_id = ? AND purpose = ?";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {

            statement.setInt(1, userId);
            statement.setString(2, purpose);
            statement.executeUpdate();
        }
    }

    // GENERATE SIX-DIGIT CODE
    private String generateVerificationCode() {
        return String.format("%06d", RANDOM.nextInt(1000000));
    }

    // GENERATE A RANDOM SESSION TOKEN
    private String generateToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);

        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(bytes);
    }

    // STORE ONLY THE SHA-256 HASH OF THE TOKEN
    private String hashToken(String token) {
        try {
            MessageDigest digest =
                    MessageDigest.getInstance("SHA-256");

            byte[] hash = digest.digest(
                    token.getBytes(StandardCharsets.UTF_8));

            StringBuilder hex = new StringBuilder();

            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }

            return hex.toString();

        } catch (Exception e) {
            throw new RuntimeException("Unable to hash token.", e);
        }
    }
}
