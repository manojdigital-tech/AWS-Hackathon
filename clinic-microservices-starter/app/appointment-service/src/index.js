import express from "express";
const app = express();
const PORT = process.env.PORT || 3002;

app.get("/health", (_, res) => res.status(200).send("OK"));
app.get("/appointment", (_, res) => res.json({ service: "appointment", ok: true }));

app.listen(PORT, () => console.log(`Appointment service on ${PORT}`));
