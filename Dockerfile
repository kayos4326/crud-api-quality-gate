# Small Node.js base image
FROM node:20-alpine

# Work inside the app folder
WORKDIR /usr/src/app

# Install packages before copying code so Docker can reuse this layer
COPY package*.json ./
RUN npm install --omit=dev

# Copy only what the API needs
COPY app.js ./
COPY prisma ./prisma
COPY dist ./dist

# Do not run the app as root
USER node

EXPOSE 3000
CMD [ "node", "app.js" ]
