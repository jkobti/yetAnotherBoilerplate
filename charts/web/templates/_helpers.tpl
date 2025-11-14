{{- define "web.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "web.fullname" -}}
{{- printf "%s-%s" (include "web.name" .) "web" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "web.labels" -}}
app.kubernetes.io/part-of: yetanotherboilerplate
app.kubernetes.io/managed-by: Helm
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}
