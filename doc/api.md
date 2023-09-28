# API

## Die Ressourcen:
- https://blog.corsego.com/rails-api-bearer-authentication

### Endpoints
- in [routes.rb](../config/routes.rb) eine Sektion im Namespace api/v1
- defaults: :json schon hier definieren

### Authentisierung
- mit einem Token (bearer) Dieses Token gehört eindeutig zum User und wird bei jedem Request geschickt.
- Dieses Token wird im Model [api_token.rb](../app/models/api_token.rb) generiert



