# Diary
## 2023-09-29
Rspec Tests der API. Diese dann swaggerized: `rake rswag:specs:swaggerize`
Die Swagger Dokumentation ist dann (api-docs/index.html)[http://0.0.0.0:3001/api-docs/index.html]
Siehe 
- [rswag](https://github.com/rswag/rswag#rswag)
- [tutorial](https://blog.corsego.com/learn-openapi-swagger-rswag)

[Problem] Wenn ich das Spec für eine API aufrufen möchte ohne authorisierung (Diese habe ich ausgschaltet), funktioniert das zwar "blutt",
aber nicht wenn das Spec mit swagger annotiert ist. Es kommt: `Response body: {"error":"You need to sign in or sign up before continuing."}`
Siehe [spec](../spec/requests/api/v1/playlists_spec.rb)
-> Lösung: Falscher Pfad korrigiert :(

## 2023-09-28
API begonnen, nach [dieser Anleitung](https://blog.corsego.com/rails-api-bearer-authentication)
- Erster Endpoint mit Dummy Response `api/v1/home/index.json`
- Dann die Authentisierung durch ein Bearer Token
  - Schwierigkeiten. 
    - Zuerst ein [key_derivation_salt generieren](https://guides.rubyonrails.org/active_record_encryption.html)
    - und in die [credentials.yml.enc](../config/credentials.yml.enc) schreiben
      - Mit dem Befehl `EDITOR="vi" bin/rails credentials:edit` öffnen und die generierten credentials reinkopieren.
      - Das Gleiche noch für development Env: `EDITOR="vi" bin/rails credentials:edit --environment development`
    - Das token für den einen User in der Rails console generieren:
```
current_user = User.first
token = current_user.api_tokens.create!
```
- Nun kann ich das JSON so abfragen: `curl -X GET "http://0.0.0.0:3001/api/v1/home/index" -H "Authorization: Bearer mySecretToken"`
- Einen [Integrationstest geschrieben](../test/integration/api_welcome_page_test.rb)

- Dann die Dokumenation nach [dieser Anleitung](https://blog.corsego.com/learn-openapi-swagger-rswag)
 - Der Pfad des swagger.yaml ist im Unterschied zur Anleitung im public Ordner
 - Auf die Authentisierung im routes.rb habe ich verzichtet
 - Die erste Endpoint-Dok mit ChatGPT gemacht...

Mehr dazu [hier](api.md)