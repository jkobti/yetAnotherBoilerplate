{{- define "admin.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "admin.fullname" -}}
{{- printf "%s-%s" (include "admin.name" .) "admin" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "admin.labels" -}}
app.kubernetes.io/part-of: yetanotherboilerplate
app.kubernetes.io/managed-by: Helm
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}
