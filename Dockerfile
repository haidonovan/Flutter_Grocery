FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

RUN useradd -m flutteruser && chown -R flutteruser:flutteruser /app
USER flutteruser

COPY pubspec.yaml pubspec.lock ./
RUN git config --global --add safe.directory /sdks/flutter
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
