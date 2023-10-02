# API
## V1: normale Rails Controller, mit rswag dokumentiert
### Die Ressourcen:
- https://blog.corsego.com/rails-api-bearer-authentication

### Endpoints
- in [routes.rb](../config/routes.rb) eine Sektion im Namespace api/v1
- defaults: :json schon hier definieren

### Authentisierung
- mit einem Token (bearer) Dieses Token gehört eindeutig zum User und wird bei jedem Request geschickt.
- Dieses Token wird im Model [api_token.rb](../app/models/api_token.rb) generiert

### Dokumentation
Im Swagger Format mit den gems "rswag-ui" und "rswag-api"
Siehe [Hier für ein Blogeintrag](https://www.doctave.com/blog/generate-openapi-swagger-spec-from-ruby-on-rails)
Die Dokumentation ist [hier](http://0.0.0.0:3001/api-docs/index.html)

## V2 mit graphiti
- Die Dokumentation zu swagger geht nicht so einfach.