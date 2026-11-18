package com.studyflow.services;

import com.studyflow.dto.TaskDTO;
import com.studyflow.dto.TaskListResponse;
import com.studyflow.dto.TaskResponse;
import com.studyflow.util.DatabaseConnection;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebService;

@WebService(serviceName = "TaskService")
public class TaskService {

    private static final Logger LOGGER =
            Logger.getLogger(TaskService.class.getName());

    private static final DateTimeFormatter DATE_FORMAT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private static final String[] VALID_PRIORITIES = {
            "LOW", "MEDIUM", "HIGH"
    };

    private static final String[] VALID_STATUSES = {
            "PENDING", "IN_PROGRESS", "DONE"
    };

    // =========================================================
    // CREATE TASK
    // =========================================================

    @WebMethod(operationName = "createTask")
    public TaskResponse createTask(
            @WebParam(name = "token") String token,
            @WebParam(name = "subjectId") String subjectId,
            @WebParam(name = "title") String title,
            @WebParam(name = "description") String description,
            @WebParam(name = "dueDate") String dueDate,
            @WebParam(name = "priority") String priority,
            @WebParam(name = "status") String status) {

        if (!isValidToken(token)) {
            return taskFailure("Authentication token is required.");
        }

        if (title == null || title.trim().isEmpty()) {
            return taskFailure("Task title is required.");
        }

        title = title.trim();

        if (title.length() > 150) {
            return taskFailure(
                    "Task title cannot exceed 150 characters.");
        }

        description = normalizeOptional(description);

        if (description != null && description.length() > 60000) {
            return taskFailure(
                    "Task description is too long.");
        }

        priority = normalizeEnum(priority);

        if (!isValidValue(priority, VALID_PRIORITIES)) {
            return taskFailure(
                    "Invalid priority. Allowed values: LOW, MEDIUM, HIGH.");
        }

        status = normalizeEnum(status);

        if (!isValidValue(status, VALID_STATUSES)) {
            return taskFailure(
                    "Invalid status. Allowed values: PENDING, IN_PROGRESS, DONE.");
        }

        Integer parsedSubjectId = parseOptionalId(subjectId);

        if (subjectId != null && !subjectId.trim().isEmpty()
                && parsedSubjectId == null) {
            return taskFailure("Invalid subject ID.");
        }

        Timestamp parsedDueDate = parseDueDate(dueDate);

        if (dueDate != null && !dueDate.trim().isEmpty()
                && parsedDueDate == null) {
            return taskFailure(
                    "Invalid due date. Expected format: yyyy-MM-dd HH:mm:ss.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return taskFailure("Invalid or expired authentication token.");
            }

            if (parsedSubjectId != null
                    && !subjectBelongsToUser(
                    connection, parsedSubjectId, userId)) {
                return taskFailure(
                        "Subject not found or does not belong to this user.");
            }

            String sql =
                    "INSERT INTO tasks "
                            + "(user_id, subject_id, title, description, "
                            + "due_date, priority, status) "
                            + "VALUES (?, ?, ?, ?, ?, ?, ?)";

            int taskId;

            try (PreparedStatement statement =
                         connection.prepareStatement(
                                 sql, Statement.RETURN_GENERATED_KEYS)) {

                statement.setInt(1, userId);

                if (parsedSubjectId == null) {
                    statement.setNull(2, java.sql.Types.INTEGER);
                } else {
                    statement.setInt(2, parsedSubjectId);
                }

                statement.setString(3, title);
                statement.setString(4, description);

                if (parsedDueDate == null) {
                    statement.setNull(5, java.sql.Types.TIMESTAMP);
                } else {
                    statement.setTimestamp(5, parsedDueDate);
                }

                statement.setString(6, priority);
                statement.setString(7, status);

                int affectedRows = statement.executeUpdate();

                if (affectedRows == 0) {
                    return taskFailure("Task could not be created.");
                }

                try (ResultSet keys = statement.getGeneratedKeys()) {

                    if (!keys.next()) {
                        return taskFailure(
                                "Task was created, but its ID could not be retrieved.");
                    }

                    taskId = keys.getInt(1);
                }
            }

            TaskDTO createdTask =
                    findTask(connection, taskId, userId);

            if (createdTask == null) {
                return taskFailure(
                        "Task was created, but could not be retrieved.");
            }

            return new TaskResponse(
                    true, "Task created successfully.", createdTask);

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Database error in createTask", e);
            return taskFailure(
                    "A database error occurred while creating the task.");
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Unexpected error in createTask", e);
            return taskFailure(
                    "An unexpected error occurred while creating the task.");
        }
    }

    // =========================================================
    // GET ALL TASKS
    // =========================================================

    @WebMethod(operationName = "getTasks")
    public TaskListResponse getTasks(
            @WebParam(name = "token") String token) {

        if (!isValidToken(token)) {
            return taskListFailure("Authentication token is required.");
        }

        List<TaskDTO> tasks = new ArrayList<>();

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return taskListFailure(
                        "Invalid or expired authentication token.");
            }

            String sql =
                    "SELECT id, subject_id, title, description, "
                            + "due_date, priority, status, created_at "
                            + "FROM tasks WHERE user_id = ? "
                            + "ORDER BY created_at DESC, id DESC";

            try (PreparedStatement statement =
                         connection.prepareStatement(sql)) {

                statement.setInt(1, userId);

                try (ResultSet resultSet = statement.executeQuery()) {

                    while (resultSet.next()) {
                        tasks.add(mapTask(resultSet));
                    }
                }
            }

            return new TaskListResponse(
                    true, "Tasks retrieved successfully.", tasks);

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Database error in getTasks", e);
            return taskListFailure(
                    "A database error occurred while retrieving tasks.");
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Unexpected error in getTasks", e);
            return taskListFailure(
                    "An unexpected error occurred while retrieving tasks.");
        }
    }

    // =========================================================
    // GET ONE TASK
    // =========================================================

    @WebMethod(operationName = "getTask")
    public TaskResponse getTask(
            @WebParam(name = "token") String token,
            @WebParam(name = "taskId") String taskId) {

        if (!isValidToken(token)) {
            return taskFailure("Authentication token is required.");
        }

        Integer parsedTaskId = parseOptionalId(taskId);

        if (parsedTaskId == null) {
            return taskFailure("Invalid task ID.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return taskFailure(
                        "Invalid or expired authentication token.");
            }

            TaskDTO task = findTask(
                    connection, parsedTaskId, userId);

            if (task == null) {
                return taskFailure(
                        "Task not found or does not belong to this user.");
            }

            return new TaskResponse(
                    true, "Task retrieved successfully.", task);

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Database error in getTask", e);
            return taskFailure(
                    "A database error occurred while retrieving the task.");
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Unexpected error in getTask", e);
            return taskFailure(
                    "An unexpected error occurred while retrieving the task.");
        }
    }

    // =========================================================
    // UPDATE TASK
    // =========================================================

    @WebMethod(operationName = "updateTask")
    public TaskResponse updateTask(
            @WebParam(name = "token") String token,
            @WebParam(name = "taskId") String taskId,
            @WebParam(name = "subjectId") String subjectId,
            @WebParam(name = "title") String title,
            @WebParam(name = "description") String description,
            @WebParam(name = "dueDate") String dueDate,
            @WebParam(name = "priority") String priority,
            @WebParam(name = "status") String status) {

        if (!isValidToken(token)) {
            return taskFailure("Authentication token is required.");
        }

        Integer parsedTaskId = parseOptionalId(taskId);

        if (parsedTaskId == null) {
            return taskFailure("Invalid task ID.");
        }

        if (title == null || title.trim().isEmpty()) {
            return taskFailure("Task title is required.");
        }

        title = title.trim();

        if (title.length() > 150) {
            return taskFailure(
                    "Task title cannot exceed 150 characters.");
        }

        description = normalizeOptional(description);

        if (description != null && description.length() > 60000) {
            return taskFailure("Task description is too long.");
        }

        priority = normalizeEnum(priority);

        if (!isValidValue(priority, VALID_PRIORITIES)) {
            return taskFailure(
                    "Invalid priority. Allowed values: LOW, MEDIUM, HIGH.");
        }

        status = normalizeEnum(status);

        if (!isValidValue(status, VALID_STATUSES)) {
            return taskFailure(
                    "Invalid status. Allowed values: PENDING, IN_PROGRESS, DONE.");
        }

        Integer parsedSubjectId = parseOptionalId(subjectId);

        if (subjectId != null && !subjectId.trim().isEmpty()
                && parsedSubjectId == null) {
            return taskFailure("Invalid subject ID.");
        }

        Timestamp parsedDueDate = parseDueDate(dueDate);

        if (dueDate != null && !dueDate.trim().isEmpty()
                && parsedDueDate == null) {
            return taskFailure(
                    "Invalid due date. Expected format: yyyy-MM-dd HH:mm:ss.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return taskFailure(
                        "Invalid or expired authentication token.");
            }

            TaskDTO existingTask =
                    findTask(connection, parsedTaskId, userId);

            if (existingTask == null) {
                return taskFailure(
                        "Task not found or does not belong to this user.");
            }

            if (parsedSubjectId != null
                    && !subjectBelongsToUser(
                    connection, parsedSubjectId, userId)) {
                return taskFailure(
                        "Subject not found or does not belong to this user.");
            }

            String sql =
                    "UPDATE tasks SET subject_id = ?, title = ?, "
                            + "description = ?, due_date = ?, priority = ?, "
                            + "status = ? WHERE id = ? AND user_id = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(sql)) {

                if (parsedSubjectId == null) {
                    statement.setNull(1, java.sql.Types.INTEGER);
                } else {
                    statement.setInt(1, parsedSubjectId);
                }

                statement.setString(2, title);
                statement.setString(3, description);

                if (parsedDueDate == null) {
                    statement.setNull(4, java.sql.Types.TIMESTAMP);
                } else {
                    statement.setTimestamp(4, parsedDueDate);
                }

                statement.setString(5, priority);
                statement.setString(6, status);
                statement.setInt(7, parsedTaskId);
                statement.setInt(8, userId);

                int affectedRows = statement.executeUpdate();

                if (affectedRows == 0) {
                    // MySQL may report zero when values did not change.
                    // Verify that the task still exists and belongs to the user.
                    TaskDTO unchangedTask =
                            findTask(connection, parsedTaskId, userId);

                    if (unchangedTask == null) {
                        return taskFailure(
                                "Task not found or could not be updated.");
                    }
                }
            }

            TaskDTO updatedTask =
                    findTask(connection, parsedTaskId, userId);

            if (updatedTask == null) {
                return taskFailure(
                        "Task was updated, but could not be retrieved.");
            }

            return new TaskResponse(
                    true, "Task updated successfully.", updatedTask);

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Database error in updateTask", e);
            return taskFailure(
                    "A database error occurred while updating the task.");
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Unexpected error in updateTask", e);
            return taskFailure(
                    "An unexpected error occurred while updating the task.");
        }
    }

    // =========================================================
    // DELETE TASK
    // =========================================================

    @WebMethod(operationName = "deleteTask")
    public TaskResponse deleteTask(
            @WebParam(name = "token") String token,
            @WebParam(name = "taskId") String taskId) {

        if (!isValidToken(token)) {
            return taskFailure("Authentication token is required.");
        }

        Integer parsedTaskId = parseOptionalId(taskId);

        if (parsedTaskId == null) {
            return taskFailure("Invalid task ID.");
        }

        try (Connection connection = DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return taskFailure(
                        "Invalid or expired authentication token.");
            }

            TaskDTO existingTask =
                    findTask(connection, parsedTaskId, userId);

            if (existingTask == null) {
                return taskFailure(
                        "Task not found or does not belong to this user.");
            }

            String sql =
                    "DELETE FROM tasks WHERE id = ? AND user_id = ?";

            try (PreparedStatement statement =
                         connection.prepareStatement(sql)) {

                statement.setInt(1, parsedTaskId);
                statement.setInt(2, userId);

                int affectedRows = statement.executeUpdate();

                if (affectedRows == 0) {
                    return taskFailure("Task could not be deleted.");
                }
            }

            return new TaskResponse(
                    true, "Task deleted successfully.", null);

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Database error in deleteTask", e);
            return taskFailure(
                    "A database error occurred while deleting the task.");
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Unexpected error in deleteTask", e);
            return taskFailure(
                    "An unexpected error occurred while deleting the task.");
        }
    }

    // =========================================================
    // AUTHENTICATION
    // =========================================================

    private int authenticateUser(Connection connection, String token)
            throws SQLException {

        String sql =
                "SELECT user_id FROM user_tokens WHERE token = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setString(1, hashToken(token));

            try (ResultSet resultSet = statement.executeQuery()) {

                if (resultSet.next()) {
                    return resultSet.getInt("user_id");
                }
            }
        }

        return -1;
    }

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
            throw new IllegalStateException(
                    "Unable to hash authentication token.", e);
        }
    }

    private boolean isValidToken(String token) {
        return token != null && !token.trim().isEmpty();
    }

    // =========================================================
    // SUBJECT OWNERSHIP
    // =========================================================

    private boolean subjectBelongsToUser(
            Connection connection, int subjectId, int userId)
            throws SQLException {

        String sql =
                "SELECT id FROM subjects WHERE id = ? AND user_id = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setInt(1, subjectId);
            statement.setInt(2, userId);

            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next();
            }
        }
    }

    // =========================================================
    // FIND TASK
    // =========================================================

    private TaskDTO findTask(
            Connection connection, int taskId, int userId)
            throws SQLException {

        String sql =
                "SELECT id, subject_id, title, description, "
                        + "due_date, priority, status, created_at "
                        + "FROM tasks WHERE id = ? AND user_id = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setInt(1, taskId);
            statement.setInt(2, userId);

            try (ResultSet resultSet = statement.executeQuery()) {

                if (resultSet.next()) {
                    return mapTask(resultSet);
                }
            }
        }

        return null;
    }

    // =========================================================
    // RESULT SET MAPPING
    // =========================================================

    private TaskDTO mapTask(ResultSet resultSet)
            throws SQLException {

        int subjectValue = resultSet.getInt("subject_id");

        Integer subjectId = resultSet.wasNull()
                ? null : subjectValue;

        Timestamp dueDate = resultSet.getTimestamp("due_date");
        Timestamp createdAt = resultSet.getTimestamp("created_at");

        return new TaskDTO(
                resultSet.getInt("id"),
                subjectId,
                resultSet.getString("title"),
                resultSet.getString("description"),
                dueDate == null ? null : dueDate.toLocalDateTime()
                        .format(DATE_FORMAT),
                resultSet.getString("priority"),
                resultSet.getString("status"),
                createdAt == null ? null : createdAt.toString()
        );
    }

    // =========================================================
    // VALIDATION HELPERS
    // =========================================================

    private Integer parseOptionalId(String value) {

        if (value == null || value.trim().isEmpty()) {
            return null;
        }

        try {
            int id = Integer.parseInt(value.trim());

            if (id <= 0) {
                return null;
            }

            return id;

        } catch (NumberFormatException e) {
            return null;
        }
    }

    private Timestamp parseDueDate(String value) {

        if (value == null || value.trim().isEmpty()) {
            return null;
        }

        try {
            LocalDateTime dateTime =
                    LocalDateTime.parse(value.trim(), DATE_FORMAT);

            return Timestamp.valueOf(dateTime);

        } catch (DateTimeParseException e) {
            return null;
        }
    }

    private String normalizeOptional(String value) {

        if (value == null || value.trim().isEmpty()) {
            return null;
        }

        return value.trim();
    }

    private String normalizeEnum(String value) {

        if (value == null) {
            return null;
        }

        return value.trim().toUpperCase();
    }

    private boolean isValidValue(String value, String[] allowedValues) {

        if (value == null) {
            return false;
        }

        for (String allowed : allowedValues) {
            if (allowed.equals(value)) {
                return true;
            }
        }

        return false;
    }

    // =========================================================
    // RESPONSE HELPERS
    // =========================================================

    private TaskResponse taskFailure(String message) {
        return new TaskResponse(false, message, null);
    }

    private TaskListResponse taskListFailure(String message) {
        return new TaskListResponse(
                false, message, new ArrayList<TaskDTO>());
    }
}