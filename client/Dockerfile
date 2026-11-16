# Stage 1: Build Flutter Web Release
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Pub get dependencies with cache
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source files
COPY . .

# Build Flutter Web in Release Mode
RUN flutter build web --release

# Stage 2: Serve with Lightweight Nginx
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
