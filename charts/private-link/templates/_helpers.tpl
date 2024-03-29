{{/*
Expand the name of the chart.
*/}}
{{- define "spl.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spl.fullname" -}}
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
{{- define "spl.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Print the namespace
*/}}
{{- define "spl.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride }}
{{- end }}

{{/*
Print the namespace for the metadata section
*/}}
{{- define "spl.metadataNamespace" -}}
{{- with .Values.namespaceOverride }}
namespace: {{ . | quote }}
{{- end }}
{{- end }}

{{/*
Set default values.
*/}}
{{- define "spl.defaultValues" }}
{{- if not .defaultValuesSet }}
  {{- $name := include "spl.fullname" . }}
  {{- include "spl.requiredValues" . }}
  {{- with .Values }}
    {{- $_ := set .deployment      "name" (.deployment.name | default $name) }}
    {{- $_ := set .serviceAccount  "name" (.serviceAccount.name | default $name) }}
    {{- $_ := set .imagePullSecret "name" (.imagePullSecret.name | default (printf "%s-regcred" $name)) }}
  {{- end }}

  {{- $values := get (include "tplYaml" (dict "doc" .Values "ctx" $) | fromJson) "doc" }}
  {{- $_ := set . "Values" $values }}

  {{- $_ := set . "defaultValuesSet" true }}
{{- end }}
{{- end }}

{{/*
Set required values.
*/}}
{{- define "spl.requiredValues" }}
  {{- with .Values }}
    {{- $_ := (.config.natsURL | required "config.platformURL is required")}}
    {{- $_ := (.config.token | required "config.token is required")}}
    {{- if and .config.tls.cert (not .config.tls.key) }}
      {{- fail "config.tls.key is required if cert is defined" }}
    {{- end }}
    {{- if and .config.tls.key (not .config.tls.cert) }}
      {{- fail "config.tls.cert is required if key is defined" }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
spl.labels
*/}}
{{- define "spl.labels" -}}
{{- with .Values.global.labels -}}
{{ toYaml . }}
{{ end -}}
helm.sh/chart: {{ include "spl.chart" . }}
{{ include "spl.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
spl.selector labels
*/}}
{{- define "spl.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spl.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: nats
{{- end }}

{{/*
Print the image
*/}}
{{- define "spl.image" }}
{{- $image := printf "%s:%s" .repository .tag }}
{{- if or .registry .global.image.registry }}
{{- $image = printf "%s/%s" (.registry | default .global.image.registry) $image }}
{{- end -}}
image: {{ $image }}
{{- if or .pullPolicy .global.image.pullPolicy }}
imagePullPolicy: {{ .pullPolicy | default .global.image.pullPolicy }}
{{- end }}
{{- end }}

{{/*
translates env var map to list
*/}}
{{- define "spl.env" -}}
{{- range $k, $v := . }}
{{- if kindIs "string" $v }}
- name: {{ $k | quote }}
  value: {{ $v | quote }}
{{- else if kindIs "map" $v }}
- {{ merge (dict "name" $k) $v | toYaml | nindent 2 }}
{{- else }}
{{- fail (cat "env var" $k "must be string or map, got" (kindOf $v)) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
List of external secretNames
*/}}
{{- define "spl.secretNames" -}}
{{- $secrets := list }}
  {{- with .Values.config.tls }}
    {{- if and .enabled .secretName }}
      {{- $secrets = append $secrets (merge (dict "name" "tls") .) }}
    {{- end }}
  {{- end }}
{{- toJson (dict "secretNames" $secrets) }}
{{- end }}

{{- /*
spl.loadMergePatch
input: map with 4 keys:
- file: name of file to load
- ctx: context to pass to tpl
- merge: interface{} to merge
- patch: []interface{} valid JSON Patch document
output: JSON encoded map with 1 key:
- doc: interface{} patched json result
*/}}
{{- define "spl.loadMergePatch" -}}
{{- $doc := tpl (.ctx.Files.Get (printf "files/%s" .file)) .ctx | fromYaml | default dict -}}
{{- $doc = mergeOverwrite $doc (deepCopy (.merge | default dict)) -}}
{{- get (include "jsonpatch" (dict "doc" $doc "patch" (.patch | default list)) | fromJson ) "doc" | toYaml -}}
{{- end }}
