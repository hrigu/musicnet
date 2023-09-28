# Diary

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


Mehr dazu [hier](api.md)