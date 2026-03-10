FROM mcr.microsoft.com/playwright:v1.50.0-noble
WORKDIR /app
COPY package.json .
RUN npm install
RUN npx playwright install chromium
COPY visual-regression.js .
RUN mkdir -p /app/screenshots/{baseline,current,diff}
CMD ["node", "visual-regression.js"]
