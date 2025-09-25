{{- define "java-ci-cd-app.name" -}}
java-ci-cd-app
{{- end -}}

{{- define "java-ci-cd-app.fullname" -}}
{{ include "java-ci-cd-app.name" . }}
{{- end -}}
