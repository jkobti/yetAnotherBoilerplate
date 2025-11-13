{{- define "api.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "api.fullname" -}}
{{- printf "%s-%s" (include "api.name" .) "api" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "api.labels" -}}
app.kubernetes.io/part-of: yetanotherboilerplate
app.kubernetes.io/managed-by: Helm
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}
