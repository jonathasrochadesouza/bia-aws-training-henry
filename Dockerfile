FROM public.ecr.aws/docker/library/node:22-slim
RUN npm install -g npm@latest --loglevel=error

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --loglevel=error

COPY client/package*.json ./client/
RUN cd client && npm install --legacy-peer-deps --loglevel=error

COPY . .

RUN cd client && VITE_API_URL=http://localhost:3001 npm run build

RUN cd client && npm prune --production && rm -rf node_modules/.cache

EXPOSE 8080

CMD [ "npm", "start" ]
