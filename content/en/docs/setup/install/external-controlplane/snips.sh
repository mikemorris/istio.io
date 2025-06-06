#!/bin/bash
# shellcheck disable=SC2034,SC2153,SC2155,SC2164

# Copyright Istio Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

####################################################################################################
# WARNING: THIS IS AN AUTO-GENERATED FILE, DO NOT EDIT. PLEASE MODIFY THE ORIGINAL MARKDOWN FILE:
#          docs/setup/install/external-controlplane/index.md
####################################################################################################

snip_set_up_a_gateway_in_the_external_cluster_1() {
cat <<EOF > controlplane-gateway.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
spec:
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          service:
            ports:
              - port: 15021
                targetPort: 15021
                name: status-port
              - port: 15012
                targetPort: 15012
                name: tls-xds
              - port: 15017
                targetPort: 15017
                name: tls-webhook
EOF
}

snip_set_up_a_gateway_in_the_external_cluster_2() {
istioctl install -f controlplane-gateway.yaml --context="${CTX_EXTERNAL_CLUSTER}"
}

snip_set_up_a_gateway_in_the_external_cluster_3() {
kubectl get po -n istio-system --context="${CTX_EXTERNAL_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_set_up_a_gateway_in_the_external_cluster_3_out <<\ENDSNIP
NAME                                   READY   STATUS    RESTARTS   AGE
istio-ingressgateway-9d4c7f5c7-7qpzz   1/1     Running   0          29s
istiod-68488cd797-mq8dn                1/1     Running   0          38s
ENDSNIP

snip_set_up_a_gateway_in_the_external_cluster_5() {
echo "$EXTERNAL_ISTIOD_ADDR" "$SSL_SECRET_NAME"
}

! IFS=$'\n' read -r -d '' snip_set_up_a_gateway_in_the_external_cluster_5_out <<\ENDSNIP
myhost.example.com myhost-example-credential
ENDSNIP

snip_set_up_a_gateway_in_the_external_cluster_6() {
export EXTERNAL_ISTIOD_ADDR=$(kubectl -n istio-system --context="${CTX_EXTERNAL_CLUSTER}" get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export SSL_SECRET_NAME=NONE
}

snip_get_remote_config_cluster_iop() {
cat <<EOF > remote-config-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: external-istiod
spec:
  profile: remote
  values:
    global:
      istioNamespace: external-istiod
      configCluster: true
    pilot:
      configMap: true
    istiodRemote:
      injectionURL: https://${EXTERNAL_ISTIOD_ADDR}:15017/inject/cluster/${REMOTE_CLUSTER_NAME}/net/network1
    base:
      validationURL: https://${EXTERNAL_ISTIOD_ADDR}:15017/validate
EOF
}

snip_set_up_the_remote_config_cluster_2() {
sed  -i'.bk' \
  -e "s|injectionURL: https://${EXTERNAL_ISTIOD_ADDR}:15017|injectionPath: |" \
  -e "/istioNamespace:/a\\
      remotePilotAddress: ${EXTERNAL_ISTIOD_ADDR}" \
  -e '/base:/,+1d' \
  remote-config-cluster.yaml; rm remote-config-cluster.yaml.bk
}

snip_set_up_the_remote_config_cluster_3() {
kubectl create namespace external-istiod --context="${CTX_REMOTE_CLUSTER}"
istioctl install -f remote-config-cluster.yaml --set values.defaultRevision=default --context="${CTX_REMOTE_CLUSTER}"
}

snip_set_up_the_remote_config_cluster_4() {
kubectl get mutatingwebhookconfiguration --context="${CTX_REMOTE_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_set_up_the_remote_config_cluster_4_out <<\ENDSNIP
NAME                                         WEBHOOKS   AGE
istio-revision-tag-default-external-istiod   4          2m2s
istio-sidecar-injector-external-istiod       4          2m5s
ENDSNIP

snip_set_up_the_remote_config_cluster_5() {
kubectl get validatingwebhookconfiguration --context="${CTX_REMOTE_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_set_up_the_remote_config_cluster_5_out <<\ENDSNIP
NAME                              WEBHOOKS   AGE
istio-validator-external-istiod   1          6m53s
istiod-default-validator          1          6m53s
ENDSNIP

snip_set_up_the_control_plane_in_the_external_cluster_1() {
kubectl create namespace external-istiod --context="${CTX_EXTERNAL_CLUSTER}"
}

snip_set_up_the_control_plane_in_the_external_cluster_2() {
istioctl create-remote-secret \
  --context="${CTX_REMOTE_CLUSTER}" \
  --type=config \
  --namespace=external-istiod \
  --service-account=istiod \
  --create-service-account=false | \
  kubectl apply -f - --context="${CTX_EXTERNAL_CLUSTER}"
}

snip_get_external_istiod_iop() {
cat <<EOF > external-istiod.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: external-istiod
spec:
  profile: empty
  meshConfig:
    rootNamespace: external-istiod
    defaultConfig:
      discoveryAddress: $EXTERNAL_ISTIOD_ADDR:15012
      proxyMetadata:
        XDS_ROOT_CA: /etc/ssl/certs/ca-certificates.crt
        CA_ROOT_CA: /etc/ssl/certs/ca-certificates.crt
  components:
    pilot:
      enabled: true
      k8s:
        overlays:
        - kind: Deployment
          name: istiod
          patches:
          - path: spec.template.spec.volumes[100]
            value: |-
              name: config-volume
              configMap:
                name: istio
          - path: spec.template.spec.volumes[100]
            value: |-
              name: inject-volume
              configMap:
                name: istio-sidecar-injector
          - path: spec.template.spec.containers[0].volumeMounts[100]
            value: |-
              name: config-volume
              mountPath: /etc/istio/config
          - path: spec.template.spec.containers[0].volumeMounts[100]
            value: |-
              name: inject-volume
              mountPath: /var/lib/istio/inject
        env:
        - name: INJECTION_WEBHOOK_CONFIG_NAME
          value: ""
        - name: VALIDATION_WEBHOOK_CONFIG_NAME
          value: ""
        - name: EXTERNAL_ISTIOD
          value: "true"
        - name: LOCAL_CLUSTER_SECRET_WATCHER
          value: "true"
        - name: CLUSTER_ID
          value: ${REMOTE_CLUSTER_NAME}
        - name: SHARED_MESH_CONFIG
          value: istio
  values:
    global:
      externalIstiod: true
      caAddress: $EXTERNAL_ISTIOD_ADDR:15012
      istioNamespace: external-istiod
      operatorManageWebhooks: true
      configValidation: false
      meshID: mesh1
      multiCluster:
        clusterName: ${REMOTE_CLUSTER_NAME}
      network: network1
EOF
}

snip_set_up_the_control_plane_in_the_external_cluster_4() {
sed  -i'.bk' \
  -e '/proxyMetadata:/,+2d' \
  -e '/INJECTION_WEBHOOK_CONFIG_NAME/{n;s/value: ""/value: istio-sidecar-injector-external-istiod/;}' \
  -e '/VALIDATION_WEBHOOK_CONFIG_NAME/{n;s/value: ""/value: istio-validator-external-istiod/;}' \
  external-istiod.yaml ; rm external-istiod.yaml.bk
}

snip_set_up_the_control_plane_in_the_external_cluster_5() {
istioctl install -f external-istiod.yaml --context="${CTX_EXTERNAL_CLUSTER}"
}

snip_set_up_the_control_plane_in_the_external_cluster_6() {
kubectl get po -n external-istiod --context="${CTX_EXTERNAL_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_set_up_the_control_plane_in_the_external_cluster_6_out <<\ENDSNIP
NAME                      READY   STATUS    RESTARTS   AGE
istiod-779bd6fdcf-bd6rg   1/1     Running   0          70s
ENDSNIP

snip_get_external_istiod_gateway_config() {
cat <<EOF > external-istiod-gw.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: external-istiod-gw
  namespace: external-istiod
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 15012
        protocol: https
        name: https-XDS
      tls:
        mode: SIMPLE
        credentialName: $SSL_SECRET_NAME
      hosts:
      - $EXTERNAL_ISTIOD_ADDR
    - port:
        number: 15017
        protocol: https
        name: https-WEBHOOK
      tls:
        mode: SIMPLE
        credentialName: $SSL_SECRET_NAME
      hosts:
      - $EXTERNAL_ISTIOD_ADDR
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
   name: external-istiod-vs
   namespace: external-istiod
spec:
    hosts:
    - $EXTERNAL_ISTIOD_ADDR
    gateways:
    - external-istiod-gw
    http:
    - match:
      - port: 15012
      route:
      - destination:
          host: istiod.external-istiod.svc.cluster.local
          port:
            number: 15012
    - match:
      - port: 15017
      route:
      - destination:
          host: istiod.external-istiod.svc.cluster.local
          port:
            number: 443
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: external-istiod-dr
  namespace: external-istiod
spec:
  host: istiod.external-istiod.svc.cluster.local
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 15012
      tls:
        mode: SIMPLE
      connectionPool:
        http:
          h2UpgradePolicy: UPGRADE
    - port:
        number: 443
      tls:
        mode: SIMPLE
EOF
}

snip_set_up_the_control_plane_in_the_external_cluster_8() {
sed  -i'.bk' \
  -e '55,$d' \
  -e 's/mode: SIMPLE/mode: PASSTHROUGH/' -e '/credentialName:/d' -e "s/${EXTERNAL_ISTIOD_ADDR}/\"*\"/" \
  -e 's/http:/tls:/' -e 's/https/tls/' -e '/route:/i\
        sniHosts:\
        - "*"' \
  external-istiod-gw.yaml; rm external-istiod-gw.yaml.bk
}

snip_set_up_the_control_plane_in_the_external_cluster_9() {
kubectl apply -f external-istiod-gw.yaml --context="${CTX_EXTERNAL_CLUSTER}"
}

snip_deploy_a_sample_application_1() {
kubectl create --context="${CTX_REMOTE_CLUSTER}" namespace sample
kubectl label --context="${CTX_REMOTE_CLUSTER}" namespace sample istio-injection=enabled
}

snip_deploy_a_sample_application_2() {
kubectl apply -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample --context="${CTX_REMOTE_CLUSTER}"
kubectl apply -f samples/helloworld/helloworld.yaml -l version=v1 -n sample --context="${CTX_REMOTE_CLUSTER}"
kubectl apply -f samples/curl/curl.yaml -n sample --context="${CTX_REMOTE_CLUSTER}"
}

snip_deploy_a_sample_application_3() {
kubectl get pod -n sample --context="${CTX_REMOTE_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_deploy_a_sample_application_3_out <<\ENDSNIP
NAME                             READY   STATUS    RESTARTS   AGE
curl-64d7d56698-wqjnm            2/2     Running   0          9s
helloworld-v1-776f57d5f6-s7zfc   2/2     Running   0          10s
ENDSNIP

snip_deploy_a_sample_application_4() {
kubectl exec --context="${CTX_REMOTE_CLUSTER}" -n sample -c curl \
    "$(kubectl get pod --context="${CTX_REMOTE_CLUSTER}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
}

! IFS=$'\n' read -r -d '' snip_deploy_a_sample_application_4_out <<\ENDSNIP
Hello version: v1, instance: helloworld-v1-776f57d5f6-s7zfc
ENDSNIP

snip_enable_gateways_1() {
cat <<EOF > istio-ingressgateway.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: ingress-install
spec:
  profile: empty
  components:
    ingressGateways:
    - namespace: external-istiod
      name: istio-ingressgateway
      enabled: true
  values:
    gateways:
      istio-ingressgateway:
        injectionTemplate: gateway
EOF
istioctl install -f istio-ingressgateway.yaml --set values.global.istioNamespace=external-istiod --context="${CTX_REMOTE_CLUSTER}"
}

snip_enable_gateways_2() {
helm install istio-ingressgateway istio/gateway -n external-istiod --kube-context="${CTX_REMOTE_CLUSTER}"
}

snip_enable_gateways_3() {
cat <<EOF > istio-egressgateway.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: egress-install
spec:
  profile: empty
  components:
    egressGateways:
    - namespace: external-istiod
      name: istio-egressgateway
      enabled: true
  values:
    gateways:
      istio-egressgateway:
        injectionTemplate: gateway
EOF
istioctl install -f istio-egressgateway.yaml --set values.global.istioNamespace=external-istiod --context="${CTX_REMOTE_CLUSTER}"
}

snip_enable_gateways_4() {
helm install istio-egressgateway istio/gateway -n external-istiod --kube-context="${CTX_REMOTE_CLUSTER}" --set service.type=ClusterIP
}

snip_configure_and_test_an_ingress_gateway_1() {
kubectl get pod -l app=istio-ingressgateway -n external-istiod --context="${CTX_REMOTE_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_configure_and_test_an_ingress_gateway_1_out <<\ENDSNIP
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-7bcd5c6bbd-kmtl4   1/1     Running   0          8m4s
ENDSNIP

snip_install_crds() {
kubectl get crd gateways.gateway.networking.k8s.io --context="${CTX_REMOTE_CLUSTER}" &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.3.0-rc.1" | kubectl apply -f - --context="${CTX_REMOTE_CLUSTER}"; }
}

snip_configure_and_test_an_ingress_gateway_3() {
kubectl apply -f samples/helloworld/helloworld-gateway.yaml -n sample --context="${CTX_REMOTE_CLUSTER}"
}

snip_configure_and_test_an_ingress_gateway_4() {
kubectl apply -f samples/helloworld/gateway-api/helloworld-gateway.yaml -n sample --context="${CTX_REMOTE_CLUSTER}"
}

snip_configure_and_test_an_ingress_gateway_5() {
export INGRESS_HOST=$(kubectl -n external-istiod --context="${CTX_REMOTE_CLUSTER}" get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n external-istiod --context="${CTX_REMOTE_CLUSTER}" get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
}

snip_configure_and_test_an_ingress_gateway_6() {
kubectl -n sample --context="${CTX_REMOTE_CLUSTER}" wait --for=condition=programmed gtw helloworld-gateway
export INGRESS_HOST=$(kubectl -n sample --context="${CTX_REMOTE_CLUSTER}" get gtw helloworld-gateway -o jsonpath='{.status.addresses[0].value}')
export GATEWAY_URL=$INGRESS_HOST:80
}

snip_configure_and_test_an_ingress_gateway_7() {
curl -s "http://${GATEWAY_URL}/hello"
}

! IFS=$'\n' read -r -d '' snip_configure_and_test_an_ingress_gateway_7_out <<\ENDSNIP
Hello version: v1, instance: helloworld-v1-776f57d5f6-s7zfc
ENDSNIP

snip_get_second_remote_cluster_iop() {
cat <<EOF > second-remote-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: external-istiod
spec:
  profile: remote
  values:
    global:
      istioNamespace: external-istiod
    istiodRemote:
      injectionURL: https://${EXTERNAL_ISTIOD_ADDR}:15017/inject/cluster/${SECOND_CLUSTER_NAME}/net/network2
EOF
}

snip_register_the_new_cluster_2() {
sed  -i'.bk' \
  -e "s|injectionURL: https://${EXTERNAL_ISTIOD_ADDR}:15017|injectionPath: |" \
  -e "/istioNamespace:/a\\
      remotePilotAddress: ${EXTERNAL_ISTIOD_ADDR}" \
  second-remote-cluster.yaml; rm second-remote-cluster.yaml.bk
}

snip_register_the_new_cluster_3() {
kubectl create namespace external-istiod --context="${CTX_SECOND_CLUSTER}"
kubectl annotate namespace external-istiod "topology.istio.io/controlPlaneClusters=${REMOTE_CLUSTER_NAME}" --context="${CTX_SECOND_CLUSTER}"
}

snip_register_the_new_cluster_4() {
istioctl install -f second-remote-cluster.yaml --context="${CTX_SECOND_CLUSTER}"
}

snip_register_the_new_cluster_5() {
kubectl get mutatingwebhookconfiguration --context="${CTX_SECOND_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_register_the_new_cluster_5_out <<\ENDSNIP
NAME                                     WEBHOOKS   AGE
istio-sidecar-injector-external-istiod   4          4m13s
ENDSNIP

snip_register_the_new_cluster_6() {
istioctl create-remote-secret \
  --context="${CTX_SECOND_CLUSTER}" \
  --name="${SECOND_CLUSTER_NAME}" \
  --type=remote \
  --namespace=external-istiod \
  --create-service-account=false | \
  kubectl apply -f - --context="${CTX_EXTERNAL_CLUSTER}"
}

snip_setup_eastwest_gateways_1() {
samples/multicluster/gen-eastwest-gateway.sh \
    --network network1 > eastwest-gateway-1.yaml
istioctl manifest generate -f eastwest-gateway-1.yaml \
    --set values.global.istioNamespace=external-istiod | \
    kubectl apply --context="${CTX_REMOTE_CLUSTER}" -f -
}

snip_setup_eastwest_gateways_2() {
samples/multicluster/gen-eastwest-gateway.sh \
    --network network2 > eastwest-gateway-2.yaml
istioctl manifest generate -f eastwest-gateway-2.yaml \
    --set values.global.istioNamespace=external-istiod | \
    kubectl apply --context="${CTX_SECOND_CLUSTER}" -f -
}

snip_setup_eastwest_gateways_3() {
kubectl --context="${CTX_REMOTE_CLUSTER}" get svc istio-eastwestgateway -n external-istiod
}

! IFS=$'\n' read -r -d '' snip_setup_eastwest_gateways_3_out <<\ENDSNIP
NAME                    TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)   AGE
istio-eastwestgateway   LoadBalancer   10.0.12.121   34.122.91.98   ...       51s
ENDSNIP

snip_setup_eastwest_gateways_4() {
kubectl --context="${CTX_SECOND_CLUSTER}" get svc istio-eastwestgateway -n external-istiod
}

! IFS=$'\n' read -r -d '' snip_setup_eastwest_gateways_4_out <<\ENDSNIP
NAME                    TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)   AGE
istio-eastwestgateway   LoadBalancer   10.0.12.121   34.122.91.99   ...       51s
ENDSNIP

snip_setup_eastwest_gateways_5() {
kubectl --context="${CTX_REMOTE_CLUSTER}" apply -n external-istiod -f \
    samples/multicluster/expose-services.yaml
}

snip_validate_the_installation_1() {
kubectl create --context="${CTX_SECOND_CLUSTER}" namespace sample
kubectl label --context="${CTX_SECOND_CLUSTER}" namespace sample istio-injection=enabled
}

snip_validate_the_installation_2() {
kubectl apply -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample --context="${CTX_SECOND_CLUSTER}"
kubectl apply -f samples/helloworld/helloworld.yaml -l version=v2 -n sample --context="${CTX_SECOND_CLUSTER}"
kubectl apply -f samples/curl/curl.yaml -n sample --context="${CTX_SECOND_CLUSTER}"
}

snip_validate_the_installation_3() {
kubectl get pod -n sample --context="${CTX_SECOND_CLUSTER}"
}

! IFS=$'\n' read -r -d '' snip_validate_the_installation_3_out <<\ENDSNIP
NAME                            READY   STATUS    RESTARTS   AGE
curl-557747455f-wtdbr           2/2     Running   0          9s
helloworld-v2-54df5f84b-9hxgw   2/2     Running   0          10s
ENDSNIP

snip_validate_the_installation_4() {
kubectl exec --context="${CTX_SECOND_CLUSTER}" -n sample -c curl \
    "$(kubectl get pod --context="${CTX_SECOND_CLUSTER}" -n sample -l app=curl -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
}

! IFS=$'\n' read -r -d '' snip_validate_the_installation_4_out <<\ENDSNIP
Hello version: v2, instance: helloworld-v2-54df5f84b-9hxgw
ENDSNIP

snip_validate_the_installation_5() {
for i in {1..10}; do curl -s "http://${GATEWAY_URL}/hello"; done
}

! IFS=$'\n' read -r -d '' snip_validate_the_installation_5_out <<\ENDSNIP
Hello version: v1, instance: helloworld-v1-776f57d5f6-s7zfc
Hello version: v2, instance: helloworld-v2-54df5f84b-9hxgw
Hello version: v1, instance: helloworld-v1-776f57d5f6-s7zfc
Hello version: v2, instance: helloworld-v2-54df5f84b-9hxgw
...
ENDSNIP

snip_cleanup_1() {
kubectl delete -f external-istiod-gw.yaml --context="${CTX_EXTERNAL_CLUSTER}"
istioctl uninstall -y --purge -f external-istiod.yaml --context="${CTX_EXTERNAL_CLUSTER}"
kubectl delete ns istio-system external-istiod --context="${CTX_EXTERNAL_CLUSTER}"
rm controlplane-gateway.yaml external-istiod.yaml external-istiod-gw.yaml
}

snip_cleanup_2() {
kubectl delete ns sample --context="${CTX_REMOTE_CLUSTER}"
istioctl uninstall -y --purge -f remote-config-cluster.yaml --set values.defaultRevision=default --context="${CTX_REMOTE_CLUSTER}"
kubectl delete ns external-istiod --context="${CTX_REMOTE_CLUSTER}"
rm remote-config-cluster.yaml istio-ingressgateway.yaml
rm istio-egressgateway.yaml eastwest-gateway-1.yaml || true
}

snip_cleanup_3() {
kubectl delete ns sample --context="${CTX_SECOND_CLUSTER}"
istioctl uninstall -y --purge -f second-remote-cluster.yaml --context="${CTX_SECOND_CLUSTER}"
kubectl delete ns external-istiod --context="${CTX_SECOND_CLUSTER}"
rm second-remote-cluster.yaml eastwest-gateway-2.yaml
}
