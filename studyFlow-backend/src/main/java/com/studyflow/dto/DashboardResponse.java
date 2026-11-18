
package com.studyflow.dto;

import java.util.ArrayList;
import java.util.List;
import javax.xml.bind.annotation.XmlAccessType;
import javax.xml.bind.annotation.XmlAccessorType;
import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

@XmlRootElement
@XmlAccessorType(XmlAccessType.FIELD)
public class DashboardResponse {

    private boolean success;
    private String message;

    private int totalSubjects;
    private int totalTasks;

    private int pendingTasks;
    private int inProgressTasks;
    private int completedTasks;

    private int overdueTasks;
    private int upcomingTasks;

    private double progressPercentage;

    @XmlElement(name = "task")
    private List<TaskDTO> nearestTasks = new ArrayList<>();

    public DashboardResponse() {
    }

    public DashboardResponse(
            boolean success,
            String message,
            int totalSubjects,
            int totalTasks,
            int pendingTasks,
            int inProgressTasks,
            int completedTasks,
            int overdueTasks,
            int upcomingTasks,
            double progressPercentage,
            List<TaskDTO> nearestTasks) {

        this.success = success;
        this.message = message;
        this.totalSubjects = totalSubjects;
        this.totalTasks = totalTasks;
        this.pendingTasks = pendingTasks;
        this.inProgressTasks = inProgressTasks;
        this.completedTasks = completedTasks;
        this.overdueTasks = overdueTasks;
        this.upcomingTasks = upcomingTasks;
        this.progressPercentage = progressPercentage;

        this.nearestTasks = nearestTasks != null
                ? nearestTasks : new ArrayList<TaskDTO>();
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public int getTotalSubjects() {
        return totalSubjects;
    }

    public void setTotalSubjects(int totalSubjects) {
        this.totalSubjects = totalSubjects;
    }

    public int getTotalTasks() {
        return totalTasks;
    }

    public void setTotalTasks(int totalTasks) {
        this.totalTasks = totalTasks;
    }

    public int getPendingTasks() {
        return pendingTasks;
    }

    public void setPendingTasks(int pendingTasks) {
        this.pendingTasks = pendingTasks;
    }

    public int getInProgressTasks() {
        return inProgressTasks;
    }

    public void setInProgressTasks(int inProgressTasks) {
        this.inProgressTasks = inProgressTasks;
    }

    public int getCompletedTasks() {
        return completedTasks;
    }

    public void setCompletedTasks(int completedTasks) {
        this.completedTasks = completedTasks;
    }

    public int getOverdueTasks() {
        return overdueTasks;
    }

    public void setOverdueTasks(int overdueTasks) {
        this.overdueTasks = overdueTasks;
    }

    public int getUpcomingTasks() {
        return upcomingTasks;
    }

    public void setUpcomingTasks(int upcomingTasks) {
        this.upcomingTasks = upcomingTasks;
    }

    public double getProgressPercentage() {
        return progressPercentage;
    }

    public void setProgressPercentage(double progressPercentage) {
        this.progressPercentage = progressPercentage;
    }

    public List<TaskDTO> getNearestTasks() {
        return nearestTasks;
    }

    public void setNearestTasks(List<TaskDTO> nearestTasks) {
        this.nearestTasks = nearestTasks != null
                ? nearestTasks : new ArrayList<TaskDTO>();
    }
}
