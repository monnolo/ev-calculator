# Stage 1: Build the app
FROM node:20 AS builder

WORKDIR /app

# Create package.json and dependencies on the fly
RUN echo '{
  "name": "ev-charge-calculator",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^5.0.0"
  }
}' > package.json

RUN npm install

# Add app source
RUN mkdir src
RUN echo '<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>EV Charge Calculator</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>' > index.html

RUN echo 'import { defineConfig } from "vite";\nimport react from "@vitejs/plugin-react";\n\nexport default defineConfig({\n  plugins: [react()],\n  build: { outDir: "dist" },\n});' > vite.config.js

RUN echo 'import React, { useState } from "react";\nimport { createRoot } from "react-dom/client";\n\nfunction App() {\n  const [batterySize, setBatterySize] = useState(77);\n  const [currentPct, setCurrentPct] = useState(40);\n  const [targetPct, setTargetPct] = useState(100);\n  const [chargerPower, setChargerPower] = useState(22);\n  const [onboardLimit, setOnboardLimit] = useState(11);\n  const [result, setResult] = useState("");\n\n  const calculate = () => {\n    const pctDiff = targetPct - currentPct;\n    if (pctDiff <= 0 || targetPct > 100 || currentPct < 0) {\n      setResult("Invalid input.");\n      return;\n    }\n    const kWhNeeded = (pctDiff / 100) * batterySize;\n    const effectivePower = Math.min(chargerPower, onboardLimit);\n    const hours = kWhNeeded / effectivePower;\n    setResult(`Charging from ${currentPct}% to ${targetPct}% will take ~${hours.toFixed(2)} hours.`);\n  };\n\n  return (\n    <div style={{ padding: "2rem", fontFamily: "sans-serif", maxWidth: 600 }}>\n      <h1>EV Charge Time Calculator</h1>\n      <div>\n        <label>Battery Size (kWh): <input type="number" value={batterySize} onChange={e => setBatterySize(+e.target.value)} /></label><br />\n        <label>Current Charge (%): <input type="number" value={currentPct} onChange={e => setCurrentPct(+e.target.value)} /></label><br />\n        <label>Target Charge (%): <input type="number" value={targetPct} onChange={e => setTargetPct(+e.target.value)} /></label><br />\n        <label>Charger Power (kW): <input type="number" value={chargerPower} onChange={e => setChargerPower(+e.target.value)} /></label><br />\n        <label>Onboard Charger Limit (kW): <input type="number" value={onboardLimit} onChange={e => setOnboardLimit(+e.target.value)} /></label><br /><br />\n        <button onClick={calculate}>Calculate</button>\n        <p style={{ marginTop: "1rem" }}>{result}</p>\n      </div>\n    </div>\n  );\n}\n\ncreateRoot(document.getElementById("root")).render(<App />);' > src/main.jsx

RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html

RUN echo 'server {\n  listen 80;\n  server_name localhost;\n  root /usr/share/nginx/html;\n  index index.html;\n  location / {\n    try_files $uri /index.html;\n  }\n}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
