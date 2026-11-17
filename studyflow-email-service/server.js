
const http = require("http");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

const PORT = 3001;

function requiredEnv(name) {
    const value = process.env[name];

    if (!value || !value.trim()) {
        throw new Error(`Missing environment variable: ${name}`);
    }

    return value.trim();
}

const senderEmail = requiredEnv("STUDYFLOW_EMAIL");
const appPassword = requiredEnv("STUDYFLOW_EMAIL_PASSWORD").replace(/\s/g, "");
const apiKey = requiredEnv("STUDYFLOW_EMAIL_API_KEY");

const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
        user: senderEmail,
        pass: appPassword
    }
});

function sendJson(response, status, data) {
    response.writeHead(status, {
        "Content-Type": "application/json; charset=utf-8"
    });
    response.end(JSON.stringify(data));
}

const server = http.createServer(async (request, response) => {

    if (request.method !== "POST" ||
        request.url !== "/send-verification-code") {
        return sendJson(response, 404, {
            success: false,
            message: "Endpoint not found"
        });
    }

    const receivedKey = request.headers["x-api-key"] || "";

    const receivedBuffer = Buffer.from(receivedKey);
    const expectedBuffer = Buffer.from(apiKey);

    if (receivedBuffer.length !== expectedBuffer.length ||
        !crypto.timingSafeEqual(receivedBuffer, expectedBuffer)) {
        return sendJson(response, 401, {
            success: false,
            message: "Unauthorized"
        });
    }

    let body = "";

    request.on("data", chunk => {
        body += chunk;

        if (body.length > 10000) {
            request.destroy();
        }
    });

    request.on("end", async () => {
        try {
            const data = JSON.parse(body);

            const recipientEmail = data.recipientEmail;
            const code = data.code;
            const purpose = data.purpose;

            if (!recipientEmail || !/^\d{6}$/.test(String(code))) {
                return sendJson(response, 400, {
                    success: false,
                    message: "Invalid email or verification code"
                });
            }

            const isPasswordReset = purpose === "PASSWORD_RESET";

            const title = isPasswordReset
                ? "Réinitialisation du mot de passe"
                : "Vérification de votre adresse e-mail";

            const description = isPasswordReset
                ? "Utilisez le code suivant pour réinitialiser votre mot de passe :"
                : "Utilisez le code suivant pour vérifier votre adresse e-mail :";

            await transporter.sendMail({
                from: `"StudyFlow" <${senderEmail}>`,
                to: recipientEmail,
                subject: isPasswordReset
                    ? "StudyFlow - Réinitialisation du mot de passe"
                    : "StudyFlow - Vérification de votre adresse e-mail",
                html: `
                    <div style="font-family:Arial,sans-serif;">
                        <h2>${title}</h2>
                        <p>${description}</p>
                        <h1 style="letter-spacing:8px;color:#2563eb;">
                            ${code}
                        </h1>
                        <p>Ce code est valable pendant 5 minutes.</p>
                        <p>Si vous n'êtes pas à l'origine de cette demande,
                        ignorez cet e-mail.</p>
                        <p>L'équipe StudyFlow</p>
                    </div>
                `
            });

            sendJson(response, 200, {
                success: true,
                message: "Email sent successfully"
            });

        } catch (error) {
            console.error("Email sending error:", error.message);

            if (!response.headersSent) {
                sendJson(response, 500, {
                    success: false,
                    message: "Email sending failed"
                });
            }
        }
    });
});

server.listen(PORT, "127.0.0.1", () => {
    console.log(`StudyFlow Email Service running on port ${PORT}`);
});
