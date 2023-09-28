# API

## Die Ressourcen:
- https://blog.corsego.com/rails-api-bearer-authentication

### Endpoints
- in [routes.rb](../config/routes.rb) eine Sektion im Namespace api/v1
- defaults: :json schon hier definieren

### Authentisierung
- mit einem Token (bearer) Dieses Token gehört eindeutig zum User und wird bei jedem Request geschickt.
- Dieses Token wird im Model [api_token.rb](../app/models/api_token.rb) generiert
  - Es verlangt ein [key_derivation_salt](https://guides.rubyonrails.org/active_record_encryption.html)
    - Also generieren wie oben beschrieben 
    - und in die [credentials.yml.enc](../config/credentials.yml.enc) schreiben
      - Mit dem Befehl `EDITOR="vi" bin/rails credentials:edit` öffnen und die generierten credentials reinkopieren.
      - Das Gleiche noch für development Env: `EDITOR="vi" bin/rails credentials:edit --environment development`
- Das token für den einen User in der Rails console generieren:
```
current_user = User.first
token = current_user.api_tokens.create!
```
- Nun kann ich das JSON so abfragen: `curl -X GET "http://0.0.0.0:3001/api/v1/home/index" -H "Authorization: Bearer mySecretToken"`




