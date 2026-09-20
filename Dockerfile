# Use a small Node.js image.
FROM node:20-alpine

# Set the app folder.
WORKDIR /usr/src/app

# Install production packages first for faster rebuilds.
COPY package*.json ./
RUN npm install --omit=dev

# Copy only the files needed to run the API.
COPY app.js ./
COPY prisma ./prisma
COPY dist ./dist

# Run without root privileges.
USER node

EXPOSE 3000
CMD [ "node", "app.js" ]
