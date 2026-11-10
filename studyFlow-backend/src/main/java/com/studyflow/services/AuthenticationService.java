
package com.studyflow.services;

import com.studyflow.dto.AuthResponse;
import com.studyflow.util.DatabaseConnection;

import javax.ejb.Stateless;
import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebService;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Base64;

import org.mindrot.jbcrypt.BCrypt;

@Stateless
@WebService(
        serviceName = "AuthenticationService",
        targetNamespace = "http://services.studyflow.com/"
)
public class AuthenticationService {

    private static final SecureRandom RANDOM = new SecureRandom();

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

        String sql = "INSERT INTO users (full_name, email, password) VALUES (?, ?, ?)";

        try (Connection connection = DatabaseConnection.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {

            String hashedPassword = BCrypt.hashpw(
                    password, BCrypt.gensalt(12));

            statement.setString(1, fullName.trim());
            statement.setString(2, email.trim().toLowerCase());
            statement.setString(3, hashedPassword);

            statement.executeUpdate();

            return new AuthResponse(true, "Account created successfully.");

        } catch (SQLException e) {
            if ("23000".equals(e.getSQLState())) {
                return new AuthResponse(false,
                        "An account with this email already exists.");
            }

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

        String sql = "SELECT id, full_name, email, password FROM users WHERE email = ?";

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
                "SELECT u.id, u.full_name, u.email " +
                        "FROM users u " +
                        "INNER JOIN user_tokens t ON u.id = t.user_id " +
                        "WHERE t.token = ?";

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
