package com.studyflow.dto;

import java.util.ArrayList;
import java.util.List;
import javax.xml.bind.annotation.XmlAccessType;
import javax.xml.bind.annotation.XmlAccessorType;
import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

@XmlRootElement
@XmlAccessorType(XmlAccessType.FIELD)
public class TaskListResponse {

    private boolean success;
    private String message;

    @XmlElement(name = "task")
    private List<TaskDTO> tasks = new ArrayList<>();

    public TaskListResponse() {
    }

    public TaskListResponse(boolean success, String message,
                            List<TaskDTO> tasks) {
        this.success = success;
        this.message = message;
        this.tasks = tasks != null ? tasks : new ArrayList<TaskDTO>();
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

    public List<TaskDTO> getTasks() {
        return tasks;
    }

    public void setTasks(List<TaskDTO> tasks) {
        this.tasks = tasks != null ? tasks : new ArrayList<TaskDTO>();
    }
}