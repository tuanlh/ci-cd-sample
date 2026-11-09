FROM mcr.microsoft.com/dotnet/sdk:10.0 AS source
WORKDIR /src
COPY . .
RUN dotnet restore CiCdSample.slnx --locked-mode

FROM source AS test
ENTRYPOINT ["dotnet", "test", "CiCdSample.slnx", "-c", "Release", "--no-restore", "--logger", "trx", "--results-directory", "/results"]

FROM source AS publish
RUN dotnet publish src/TaskApi/TaskApi.csproj -c Release --no-restore -o /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=publish /app .
ARG APP_VERSION=local
ENV APP_VERSION=$APP_VERSION
ENV ASPNETCORE_HTTP_PORTS=8080
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "TaskApi.dll"]
