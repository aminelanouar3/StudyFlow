
package com.studyflow.services;

import com.studyflow.dto.DashboardResponse;
import com.studyflow.dto.TaskDTO;
import com.studyflow.util.DatabaseConnection;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebService;

@WebService(serviceName = "DashboardService")
public class DashboardService {

    private static final Logger LOGGER =
            Logger.getLogger(DashboardService.class.getName());

    private static final DateTimeFormatter DATE_FORMAT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @WebMethod(operationName = "getDashboard")
    public DashboardResponse getDashboard(
            @WebParam(name = "token") String token) {

        if (token == null || token.trim().isEmpty()) {
            return dashboardFailure(
                    "Authentication token is required.");
        }

        try (Connection connection =
                     DatabaseConnection.getConnection()) {

            int userId = authenticateUser(connection, token);

            if (userId == -1) {
                return dashboardFailure(
                        "Invalid or expired authentication token.");
            }

            int totalSubjects = getTotalSubjects(connection, userId);

            TaskStatistics statistics =
                    getTaskStatistics(connection, userId);

            List<TaskDTO> nearestTasks =
                    getNearestTasks(connection, userId);

            int totalTasks = statistics.totalTasks;

            double progressPercentage = totalTasks == 0
                    ? 0.0
                    : (statistics.completedTasks * 100.0)
                      / totalTasks;

            progressPercentage =
                    Math.round(progressPercentage * 100.0) / 100.0;

            return new DashboardResponse(
                    true,
                    "Dashboard retrieved successfully.",
                    totalSubjects,
                    totalTasks,
                    statistics.pendingTasks,
                    statistics.inProgressTasks,
                    statistics.completedTasks,
                    statistics.overdueTasks,
                    statistics.upcomingTasks,
                    progressPercentage,
                    nearestTasks
            );

        } catch (SQLException e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Database error in getDashboard",
                    e
            );

            return dashboardFailure(
                    "A database error occurred while retrieving the dashboard.");

        } catch (Exception e) {

            LOGGER.log(
                    Level.SEVERE,
                    "Unexpected error in getDashboard",
                    e
            );

            return dashboardFailure(
                    "An unexpected error occurred while retrieving the dashboard.");
        }
    }

    // =========================================================
    // AUTHENTICATION
    // =========================================================

    private int authenticateUser(
            Connection connection, String token)
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

    // =========================================================
    // SUBJECT STATISTICS
    // =========================================================

    private int getTotalSubjects(
            Connection connection, int userId)
            throws SQLException {

        String sql =
                "SELECT COUNT(*) AS total "
                        + "FROM subjects WHERE user_id = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setInt(1, userId);

            try (ResultSet resultSet = statement.executeQuery()) {

                if (resultSet.next()) {
                    return resultSet.getInt("total");
                }
            }
        }

        return 0;
    }

    // =========================================================
    // TASK STATISTICS
    // =========================================================

    private TaskStatistics getTaskStatistics(
            Connection connection, int userId)
            throws SQLException {

        String sql =
                "SELECT "
                        + "COUNT(*) AS total_tasks, "

                        + "COALESCE(SUM(CASE "
                        + "WHEN status = 'PENDING' THEN 1 "
                        + "ELSE 0 END), 0) AS pending_tasks, "

                        + "COALESCE(SUM(CASE "
                        + "WHEN status = 'IN_PROGRESS' THEN 1 "
                        + "ELSE 0 END), 0) AS in_progress_tasks, "

                        + "COALESCE(SUM(CASE "
                        + "WHEN status = 'DONE' THEN 1 "
                        + "ELSE 0 END), 0) AS completed_tasks, "

                        + "COALESCE(SUM(CASE "
                        + "WHEN status <> 'DONE' "
                        + "AND due_date IS NOT NULL "
                        + "AND due_date < CURRENT_TIMESTAMP "
                        + "THEN 1 ELSE 0 END), 0) AS overdue_tasks, "

                        + "COALESCE(SUM(CASE "
                        + "WHEN status <> 'DONE' "
                        + "AND due_date IS NOT NULL "
                        + "AND due_date >= CURRENT_TIMESTAMP "
                        + "THEN 1 ELSE 0 END), 0) AS upcoming_tasks "

                        + "FROM tasks WHERE user_id = ?";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setInt(1, userId);

            try (ResultSet resultSet = statement.executeQuery()) {

                if (resultSet.next()) {

                    TaskStatistics statistics =
                            new TaskStatistics();

                    statistics.totalTasks =
                            resultSet.getInt("total_tasks");

                    statistics.pendingTasks =
                            resultSet.getInt("pending_tasks");

                    statistics.inProgressTasks =
                            resultSet.getInt("in_progress_tasks");

                    statistics.completedTasks =
                            resultSet.getInt("completed_tasks");

                    statistics.overdueTasks =
                            resultSet.getInt("overdue_tasks");

                    statistics.upcomingTasks =
                            resultSet.getInt("upcoming_tasks");

                    return statistics;
                }
            }
        }

        return new TaskStatistics();
    }

    // =========================================================
    // FIVE NEAREST TASK DEADLINES
    // =========================================================

    private List<TaskDTO> getNearestTasks(
            Connection connection, int userId)
            throws SQLException {

        List<TaskDTO> tasks = new ArrayList<>();

        String sql =
                "SELECT id, subject_id, title, description, "
                        + "due_date, priority, status, created_at "
                        + "FROM tasks "
                        + "WHERE user_id = ? "
                        + "AND due_date IS NOT NULL "
                        + "AND status <> 'DONE' "

                        // Overdue tasks first.
                        // Among overdue tasks, show the most recently
                        // overdue first.
                        // Then show future deadlines in ascending order.
                        + "ORDER BY "
                        + "CASE WHEN due_date < CURRENT_TIMESTAMP "
                        + "THEN 0 ELSE 1 END ASC, "

                        + "CASE WHEN due_date < CURRENT_TIMESTAMP "
                        + "THEN due_date END DESC, "

                        + "due_date ASC "

                        + "LIMIT 5";

        try (PreparedStatement statement =
                     connection.prepareStatement(sql)) {

            statement.setInt(1, userId);

            try (ResultSet resultSet = statement.executeQuery()) {

                while (resultSet.next()) {

                    tasks.add(mapTask(resultSet));
                }
            }
        }

        return tasks;
    }

    // =========================================================
    // TASK MAPPING
    // =========================================================

    private TaskDTO mapTask(ResultSet resultSet)
            throws SQLException {

        int subjectValue = resultSet.getInt("subject_id");

        Integer subjectId = resultSet.wasNull()
                ? null : subjectValue;

        Timestamp dueDate =
                resultSet.getTimestamp("due_date");

        Timestamp createdAt =
                resultSet.getTimestamp("created_at");

        return new TaskDTO(
                resultSet.getInt("id"),
                subjectId,
                resultSet.getString("title"),
                resultSet.getString("description"),
                dueDate == null
                        ? null
                        : dueDate.toLocalDateTime()
                        .format(DATE_FORMAT),
                resultSet.getString("priority"),
                resultSet.getString("status"),
                createdAt == null
                        ? null
                        : createdAt.toString()
        );
    }

    // =========================================================
    // INTERNAL STATISTICS
    // =========================================================

    private static class TaskStatistics {

        private int totalTasks;
        private int pendingTasks;
        private int inProgressTasks;
        private int completedTasks;
        private int overdueTasks;
        private int upcomingTasks;
    }

    // =========================================================
    // RESPONSE
    // =========================================================

    private DashboardResponse dashboardFailure(String message) {

        return new DashboardResponse(
                false,
                message,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0.0,
                new ArrayList<TaskDTO>()
        );
    }
}
