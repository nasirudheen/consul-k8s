{{- if eq .Column 1 }}### `{{ .Key }}`

{{ .FormattedDocumentation }}

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |{{ else }}{{ .Row }}{{ end }}