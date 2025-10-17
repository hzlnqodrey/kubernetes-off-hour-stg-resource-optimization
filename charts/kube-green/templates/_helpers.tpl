{{/*
Expand the name of the chart.
*/}}
{{- define "kube-green.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kube-green.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kube-green.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kube-green.labels" -}}
helm.sh/chart: {{ include "kube-green.chart" . }}
{{ include "kube-green.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kube-green.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-green.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kube-green.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kube-green.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the namespace to use
*/}}
{{- define "kube-green.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create the image name
*/}}
{{- define "kube-green.image" -}}
{{- $registry := .Values.global.imageRegistry | default "" }}
{{- $repository := .Values.image.repository }}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Create common annotations
*/}}
{{- define "kube-green.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create certificate name
*/}}
{{- define "kube-green.certificateName" -}}
{{- printf "%s-serving-cert" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create webhook service name
*/}}
{{- define "kube-green.webhookServiceName" -}}
{{- printf "%s-webhook-service" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create metrics service name
*/}}
{{- define "kube-green.metricsServiceName" -}}
{{- printf "%s-metrics-service" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create leader election role name
*/}}
{{- define "kube-green.leaderElectionRoleName" -}}
{{- printf "%s-leader-election-role" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create manager role name
*/}}
{{- define "kube-green.managerRoleName" -}}
{{- printf "%s-manager-role" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create proxy role name
*/}}
{{- define "kube-green.proxyRoleName" -}}
{{- printf "%s-proxy-role" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create metrics reader role name
*/}}
{{- define "kube-green.metricsReaderRoleName" -}}
{{- printf "%s-metrics-reader" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create manager role binding name
*/}}
{{- define "kube-green.managerRoleBindingName" -}}
{{- printf "%s-manager-rolebinding" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create proxy role binding name
*/}}
{{- define "kube-green.proxyRoleBindingName" -}}
{{- printf "%s-proxy-rolebinding" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create leader election role binding name
*/}}
{{- define "kube-green.leaderElectionRoleBindingName" -}}
{{- printf "%s-leader-election-rolebinding" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create mutating webhook configuration name
*/}}
{{- define "kube-green.mutatingWebhookConfigurationName" -}}
{{- printf "%s-mutating-webhook-configuration" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Create validating webhook configuration name
*/}}
{{- define "kube-green.validatingWebhookConfigurationName" -}}
{{- printf "%s-validating-webhook-configuration" (include "kube-green.fullname" .) }}
{{- end }}

{{/*
Get image pull secrets
*/}}
{{- define "kube-green.imagePullSecrets" -}}
{{- $secrets := concat (.Values.global.imagePullSecrets | default list) (.Values.imagePullSecrets | default list) }}
{{- if $secrets }}
imagePullSecrets:
{{- range $secrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}
