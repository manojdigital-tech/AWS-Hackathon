import express from "express";
const app = express();
const PORT = process.env.PORT || 3001;

app.get("/health", (_, res) => res.status(200).send("OK"));
app.get("/patient", (_, res) => res.json({ service: "patient", ok: true }));

app.listen(PORT, () => console.log(`Patient service on ${PORT}`));
