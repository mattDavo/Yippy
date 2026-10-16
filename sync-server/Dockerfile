# Builds the sync server into a small image. Build from this folder: docker build -t clip-sync-server .
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /source
COPY Directory.Build.props .
COPY src/SyncServer/SyncServer.csproj src/SyncServer/
RUN dotnet restore src/SyncServer/SyncServer.csproj
COPY src/ src/
RUN dotnet publish src/SyncServer/SyncServer.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app .
# The database lives in /data, which the non-root user must be able to write
RUN mkdir /data && chown app /data
ENV ASPNETCORE_HTTP_PORTS=8080 \
    SYNC_DB_PATH=/data/sync.db
VOLUME /data
EXPOSE 8080
# The aspnet image's non-root user
USER app
ENTRYPOINT ["dotnet", "SyncServer.dll"]
