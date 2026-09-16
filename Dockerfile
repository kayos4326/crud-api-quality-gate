# Stage 1: Base Image (Alpine Linux is incredibly small and secure)
FROM node:20-alpine

# Stage 2: Set the working directory inside the container
WORKDIR /usr/src/app

# Stage 3: Install Dependencies (Optimized for Layer Caching)
COPY package*.json ./
RUN npm install --omit=dev

# Stage 4: Copy source explicitly.
# "COPY . ." would pull in anything not caught by .dockerignore - including a
# compose file or .env holding live credentials. Name what ships instead.
COPY app.js ./
COPY prisma ./prisma
COPY dist ./dist

# Stage 5: Drop root. The node image provides an unprivileged "node" user.
USER node

EXPOSE 3000
CMD [ "node", "app.js" ]
