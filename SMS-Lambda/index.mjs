import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";

export const handler = async (event) => {
  const client = new SNSClient({});

  try {
    const { phoneNumber, countryCode, message } = JSON.parse(event.body);

    if (!phoneNumber || !countryCode || !message) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: "Parámetros faltantes: phoneNumber, countryCode o message.",
        }),
      };
    }

    const params = {
      Message: message,
      PhoneNumber: `+${countryCode}${phoneNumber}`,
    };

    const command = new PublishCommand(params);
    const result = await client.send(command);

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: "SMS enviado exitosamente.",
        result: result,
      }),
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: "Ocurrió un error.",
        error: error.message || "Error desconocido",
      }),
    };
  }
};
