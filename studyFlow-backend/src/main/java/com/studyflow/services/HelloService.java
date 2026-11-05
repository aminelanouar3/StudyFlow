
package com.studyflow.services;

import javax.jws.WebMethod;
import javax.jws.WebService;

@WebService(
        serviceName = "HelloService",
        targetNamespace = "http://services.studyflow.com/"
)
public class HelloService {

    @WebMethod
    public String hello(String name) {
        return "Welcome to StudyFlow, " + name + "!";
    }
}
