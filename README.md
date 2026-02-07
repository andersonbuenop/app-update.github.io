# app-update
Verifica se apps importados do csv estao na sua ultima versao, mostrando status, se esta atualizado, se tem atualizacao, etc

Ideias futuras de ajuste

- Automatização do csv extraido do sccm, como base para scraping check
- Menssagem automatica de app que precisa ser atualizado email/teams
- Coluna de tipo de licença "free" ou "licenciado" check
- Coluna de observação, para comentar alguma informação util do app check
- Opção de editar os parametros do app(appSources.json) visualmente check
- Quando identificar um app com status "Unknow", ao invez de ajustar manualmente o appSource.json, exibir/sugerir, mostrar uma informação no top da pagina, com link de uma janela de update, para preenchimento dos campos de forma visual, agilizando a manutenção e evitando editar o codigo manualmente.
- Mudar a ordem de visualização da lista, hoje esta exibindo confirme a ordem lida no csv, para exibir prineiro os "UpadateAvailable"
- Historico dos updates com comentarios
- Grafico com dados dos status check
- remover coluna versao app
-  inserir uma coluna app interno e app externo
-  definir um calendario interno, onde eu veja o novo update apenas apos esse periodo, exemplo, google chrome atualizo a cada 15 dias, entao eu seto ou ele percebe que foi atualziar a ultima versao instalada hoje, e vai mostrar a ova versao apos passar 15 dias, ou continuar mostrando como ja esta, mas em 15 dias, sobe uma alerta tipo o NEW, para atualziado o ambiente
