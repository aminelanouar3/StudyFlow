
package com.studyflow.services;

import com.studyflow.dto.SubjectDTO;
import com.studyflow.dto.SubjectResponse;
import com.studyflow.dto.SubjectListResponse;
import com.studyflow.util.DatabaseConnection;

import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebService;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

@WebService(serviceName = "SubjectService")
public class SubjectService {

    private static final Logger LOGGER =
            Logger.getLogger(SubjectService.class.getName());

    // =====================================================
    // CREATE SUBJECT
    // =====================================================

    @WebMethod(operationName = "createSubject")
    public SubjectResponse createSubject(
            @WebParam(name = "token") String token,
            @WebParam(name = "name") String name,
            @WebParam(name = "description") String description,
            @WebParam(name = "color") String color) {

        if (token == null || token.trim().isEmpty()) {
            return new SubjectResponse(false, "Token is required.");
        }

        token = token.trim();

        if (name == null || name.trim().isEmpty()) {
            return new SubjectResponse(false, "Subject name is required.");
        }

        name = name.trim();

        if (name.length() > 100) {
            return new SubjectResponse(
                    false,
                    "Subject name must not exceed 100 characters."
            );
        }

        if (color == null || color.trim().isEmpty()) {
            return new SubjectResponse(false, "Subject color is required.");
        }

        color = color.trim();

        if (color.length() > 20) {
            return new SubjectResponse(false, "Invalid subject color.");
        }

        if (description != null) {
            description = description.trim();

            if (description.isEmpty()) {
                description = null;
            }
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return new SubjectResponse(
                        false,
                        "Invalid or expired session."
                );
            }

            String sql =
                    "INSERT INTO subjects (user_id, name, description, color) " +
                            "VALUES (?, ?, ?, ?)";

            try (PreparedStatement statement =
                         connection.prepareStatement(
                                 sql,
                                 Statement.RETURN_GENERATED_KEYS)) {

                statement.setInt(1, userId);
                statement.setString(2, name);
                statement.setString(3, description);
                statement.setString(4, color);

                int inserted = statement.executeUpdate();

                if (inserted != 1) {
                    return new SubjectResponse(
                            false,
                            "Unable to create subject."
                    );
                }

                try (ResultSet keys = statement.getGeneratedKeys()) {

                    if (keys.next()) {

                        int subjectId = keys.getInt(1);

                        SubjectDTO subject =
                                findSubject(connection, subjectId, userId);

                        if (subject == null) {
                            return new SubjectResponse(
                                    false,
                                    "Subject was created but could not be retrieved."
                            );
                        }

                        SubjectResponse response =
                                new SubjectResponse(
                                        true,
                                        "Subject created successfully."
                                );

                        response.setSubject(subject);

                        return response;
                    }
                }
            }

            return new SubjectResponse(false, "Unable to create subject.");

        } catch (SQLException e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Database error while creating subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Database error while creating subject."
            );

        } catch (Exception e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Unexpected error while creating subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Unexpected server error while creating subject."
            );
        }
    }

    // =====================================================
    // GET ALL USER SUBJECTS
    // =====================================================

    @WebMethod(operationName = "getSubjects")
    public SubjectListResponse getSubjects(
            @WebParam(name = "token") String token) {

        if (token == null || token.trim().isEmpty()) {
            return new SubjectListResponse(false, "Token is required.");
        }

        token = token.trim();

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return new SubjectListResponse(
                        false,
                        "Invalid or expired session."
                );
            }

            String sql =
                    "SELECT id, name, description, color, created_at " +
                            "FROM subjects " +
                            "WHERE user_id = ? " +
                            "ORDER BY created_at DESC";

            List<SubjectDTO> subjects = new ArrayList<>();

            try (PreparedStatement statement =
                         connection.prepareStatement(sql)) {

                statement.setInt(1, userId);

                try (ResultSet result = statement.executeQuery()) {

                    while (result.next()) {
                        subjects.add(mapSubject(result));
                    }
                }
            }

            SubjectListResponse response =
                    new SubjectListResponse(
                            true,
                            "Subjects retrieved successfully."
                    );

            response.setSubjects(subjects);

            return response;

        } catch (SQLException e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Database error while retrieving subjects.",
                    e
            );

            return new SubjectListResponse(
                    false,
                    "Database error while retrieving subjects."
            );

        } catch (Exception e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Unexpected error while retrieving subjects.",
                    e
            );

            return new SubjectListResponse(
                    false,
                    "Unexpected server error while retrieving subjects."
            );
        }
    }

    // =====================================================
    // GET ONE SUBJECT
    // =====================================================

    @WebMethod(operationName = "getSubject")
    public SubjectResponse getSubject(
            @WebParam(name = "token") String token,
            @WebParam(name = "subjectId") String subjectId) {

        if (token == null || token.trim().isEmpty()) {
            return new SubjectResponse(false, "Token is required.");
        }

        token = token.trim();

        Integer parsedSubjectId = parseSubjectId(subjectId);

        if (parsedSubjectId == null) {
            return new SubjectResponse(false, "Invalid subject ID.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return new SubjectResponse(
                        false,
                        "Invalid or expired session."
                );
            }

            SubjectDTO subject =
                    findSubject(connection, parsedSubjectId, userId);

            if (subject == null) {
                return new SubjectResponse(false, "Subject not found.");
            }

            SubjectResponse response =
                    new SubjectResponse(
                            true,
                            "Subject retrieved successfully."
                    );

            response.setSubject(subject);

            return response;

        } catch (SQLException e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Database error while retrieving subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Database error while retrieving subject."
            );

        } catch (Exception e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Unexpected error while retrieving subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Unexpected server error while retrieving subject."
            );
        }
    }

    // =====================================================
    // UPDATE SUBJECT
    // =====================================================

    @WebMethod(operationName = "updateSubject")
    public SubjectResponse updateSubject(
            @WebParam(name = "token") String token,
            @WebParam(name = "subjectId") String subjectId,
            @WebParam(name = "name") String name,
            @WebParam(name = "description") String description,
            @WebParam(name = "color") String color) {

        if (token == null || token.trim().isEmpty()) {
            return new SubjectResponse(false, "Token is required.");
        }

        token = token.trim();

        Integer parsedSubjectId = parseSubjectId(subjectId);

        if (parsedSubjectId == null) {
            return new SubjectResponse(false, "Invalid subject ID.");
        }

        if (name == null || name.trim().isEmpty()) {
            return new SubjectResponse(
                    false,
                    "Subject name is required."
            );
        }

        name = name.trim();

        if (name.length() > 100) {
            return new SubjectResponse(
                    false,
                    "Subject name must not exceed 100 characters."
            );
        }

        if (color == null || color.trim().isEmpty()) {
            return new SubjectResponse(
                    false,
                    "Subject color is required."
            );
        }

        color = color.trim();

        if (color.length() > 20) {
            return new SubjectResponse(false, "Invalid subject color.");
        }

        if (description != null) {
            description = description.trim();

            if (description.isEmpty()) {
                description = null;
            }
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return new SubjectResponse(
                        false,
                        "Invalid or expired session."
                );
            }

            SubjectDTO existingSubject =
                    findSubject(connection, parsedSubjectId, userId);

            if (existingSubject == null) {
                return new SubjectResponse(false, "Subject not found.");
            }

            String sql =
                    "UPDATE subjects " +
                            "SET name = ?, description = ?, color = ? " +
                            "WHERE id = ? AND user_id = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(sql)) {

                statement.setString(1, name);
                statement.setString(2, description);
                statement.setString(3, color);
                statement.setInt(4, parsedSubjectId);
                statement.setInt(5, userId);

                statement.executeUpdate();
            }

            SubjectDTO updatedSubject =
                    findSubject(connection, parsedSubjectId, userId);

            if (updatedSubject == null) {
                return new SubjectResponse(
                        false,
                        "Unable to retrieve updated subject."
                );
            }

            SubjectResponse response =
                    new SubjectResponse(
                            true,
                            "Subject updated successfully."
                    );

            response.setSubject(updatedSubject);

            return response;

        } catch (SQLException e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Database error while updating subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Database error while updating subject."
            );

        } catch (Exception e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Unexpected error while updating subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Unexpected server error while updating subject."
            );
        }
    }

    // =====================================================
    // DELETE SUBJECT
    //
    // deleteTasks = true:
    //     Delete the subject and all its tasks.
    //
    // deleteTasks = false:
    //     Delete only the subject.
    //     The database ON DELETE SET NULL constraint
    //     preserves its tasks with subject_id = NULL.
    // =====================================================

    @WebMethod(operationName = "deleteSubject")
    public SubjectResponse deleteSubject(
            @WebParam(name = "token") String token,
            @WebParam(name = "subjectId") String subjectId,
            @WebParam(name = "deleteTasks") boolean deleteTasks) {

        if (token == null || token.trim().isEmpty()) {
            return new SubjectResponse(false, "Token is required.");
        }

        token = token.trim();

        Integer parsedSubjectId = parseSubjectId(subjectId);

        if (parsedSubjectId == null) {
            return new SubjectResponse(false, "Invalid subject ID.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return new SubjectResponse(
                        false,
                        "Invalid or expired session."
                );
            }

            connection.setAutoCommit(false);

            try {

                // Verify that the subject belongs to this user.
                // FOR UPDATE locks the subject row during deletion.
                String checkSql =
                        "SELECT id FROM subjects " +
                                "WHERE id = ? AND user_id = ? " +
                                "FOR UPDATE";

                boolean subjectExists;

                try (PreparedStatement statement =
                             connection.prepareStatement(checkSql)) {

                    statement.setInt(1, parsedSubjectId);
                    statement.setInt(2, userId);

                    try (ResultSet result = statement.executeQuery()) {
                        subjectExists = result.next();
                    }
                }

                if (!subjectExists) {
                    connection.rollback();

                    return new SubjectResponse(
                            false,
                            "Subject not found."
                    );
                }

                // Option 1: delete all tasks belonging to this subject.
                if (deleteTasks) {

                    String deleteTasksSql =
                            "DELETE FROM tasks " +
                                    "WHERE subject_id = ? AND user_id = ?";

                    try (PreparedStatement statement =
                                 connection.prepareStatement(deleteTasksSql)) {

                        statement.setInt(1, parsedSubjectId);
                        statement.setInt(2, userId);

                        statement.executeUpdate();
                    }
                }

                // Option 2: when deleteTasks is false,
                // ON DELETE SET NULL preserves the tasks.
                String deleteSubjectSql =
                        "DELETE FROM subjects " +
                                "WHERE id = ? AND user_id = ?";

                int deleted;

                try (PreparedStatement statement =
                             connection.prepareStatement(deleteSubjectSql)) {

                    statement.setInt(1, parsedSubjectId);
                    statement.setInt(2, userId);

                    deleted = statement.executeUpdate();
                }

                if (deleted != 1) {
                    connection.rollback();

                    return new SubjectResponse(
                            false,
                            "Unable to delete subject."
                    );
                }

                connection.commit();

                if (deleteTasks) {
                    return new SubjectResponse(
                            true,
                            "Subject and its tasks deleted successfully."
                    );
                }

                return new SubjectResponse(
                        true,
                        "Subject deleted successfully. Its tasks were preserved without a subject."
                );

            } catch (SQLException | RuntimeException e) {

                connection.rollback();
                throw e;
            }

        } catch (SQLException e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Database error while deleting subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Database error while deleting subject."
            );

        } catch (Exception e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Unexpected error while deleting subject.",
                    e
            );

            return new SubjectResponse(
                    false,
                    "Unexpected server error while deleting subject."
            );
        }
    }

    // =====================================================
    // VALIDATE AND PARSE SUBJECT ID
    // =====================================================

    private Integer parseSubjectId(String subjectId) {

        if (subjectId == null || subjectId.trim().isEmpty()) {
            return null;
        }

        try {

            int id = Integer.parseInt(subjectId.trim());

            if (id <= 0) {
                return null;
            }

            return id;

        } catch (NumberFormatException e) {
            return null;
        }
    }

    // =====================================================
    // AUTHENTICATE USER USING SESSION TOKEN
    // =====================================================

    private int authenticateUser(Connection connection, String token)
            throws Exception {

        String sql =
                "SELECT user_id FROM user_tokens WHERE token = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setString(1, hashToken(token));

            try (ResultSet result = statement.executeQuery()) {

                if (result.next()) {
                    return result.getInt("user_id");
                }
            }
        }

        return -1;
    }

    // =====================================================
    // FIND SUBJECT BELONGING TO A SPECIFIC USER
    // =====================================================

    private SubjectDTO findSubject(
            Connection connection,
            int subjectId,
            int userId) throws SQLException {

        String sql =
                "SELECT id, name, description, color, created_at " +
                        "FROM subjects " +
                        "WHERE id = ? AND user_id = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setInt(1, subjectId);
            statement.setInt(2, userId);

            try (ResultSet result = statement.executeQuery()) {

                if (result.next()) {
                    return mapSubject(result);
                }
            }
        }

        return null;
    }

    // =====================================================
    // MAP DATABASE RESULT TO SUBJECT DTO
    // =====================================================

    private SubjectDTO mapSubject(ResultSet result)
            throws SQLException {

        SubjectDTO subject = new SubjectDTO();

        subject.setId(result.getInt("id"));
        subject.setName(result.getString("name"));
        subject.setDescription(result.getString("description"));
        subject.setColor(result.getString("color"));

        java.sql.Timestamp createdAt =
                result.getTimestamp("created_at");

        subject.setCreatedAt(
                createdAt == null ? null : createdAt.toString()
        );

        return subject;
    }

    // =====================================================
    // SHA-256 TOKEN HASHING
    // SAME ALGORITHM AS AUTHENTICATION SERVICE
    // =====================================================

    private String hashToken(String token) throws Exception {

        MessageDigest digest =
                MessageDigest.getInstance("SHA-256");

        byte[] hash = digest.digest(
                token.getBytes(StandardCharsets.UTF_8)
        );

        StringBuilder hex = new StringBuilder();

        for (byte b : hash) {
            hex.append(String.format("%02x", b));
        }

        return hex.toString();
    }
}
