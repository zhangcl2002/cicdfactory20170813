#!/bin/bash

if [ $# -lt 8 ]; then
    echo "k8s-deploy command usage: ./k8s-deploy.sh imageLibrary appName replicas expose_service domain_name context_path docker_tag probe_path kubeconfig"
    exit 1
fi

export KUBECONFIG=$HOME/admin.conf


if  kubectl --kubeconfig /root/${9}.conf get svc $2-nginx-svc| grep $2-nginx-svc > /dev/null; then

    kubectl --kubeconfig /root/${9}.conf set image deployment/$2-nginx-deployment $2-nginx=registry.aegonthtf.com/$1/$2:$7

else
     cat << EOF > application.yaml 
kind: Service
apiVersion: v1
metadata:
  name: $2-nginx-svc
spec:
  ports:
    - name: http
      port: 80
      targetPort: 80
  selector:
      app: $2-nginx
  type: ClusterIP
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name:  $2-nginx-deployment
  namespace: default
  labels:
    app:  $2-nginx
spec:
  replicas: $3
  template:
    metadata:
      labels:
        app: $2-nginx
    spec:
      terminationGracePeriodSeconds: 35
      containers:
      - name: $2-nginx
        image: registry.aegonthtf.com/$1/$2:$7
        imagePullPolicy: Always
        readinessProbe:
          httpGet:
            path: $8
            port: 80
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 6
          successThreshold: 1
          failureThreshold: 5
        livenessProbe:  
          httpGet:
            path: $8
            port: 80
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 6
          successThreshold: 1
          failureThreshold: 5      
        ports:
          - name: http
            containerPort: 80

EOF
     kubectl --kubeconfig /root/${9}.conf create -f application.yaml

  # 需要暴露Service
  if [[ $4 == "true" ]]
  then
                              
      # 选定域名是否存在，若存在，则需要Append本项目的设置, 若不存在，则新建
      if kubectl --kubeconfig /root/${9}.conf get ingress $5 | grep $5 > /dev/null;
      then
      
          if ls k8s-dev-ingress/$5.yaml | grep $5 > /dev/null;
          then
               if grep -wq "$2-nginx-svc" k8s-dev-ingress/$5.yaml;
               then
                  echo ' ';
               else
                 cat << EOF >> k8s-dev-ingress/$5.yaml
      - path: $6
        backend:
          serviceName: $2-nginx-svc
          servicePort: 80
EOF
                fi
          else
              echo 'No appropriat ingress yaml file exists, please check';
          fi
        
          kubectl --kubeconfig /root/${9}.conf replace -f k8s-dev-ingress/$5.yaml

      else

        
         cat << EOF > k8s-dev-ingress/$5.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: $5
spec:
  rules:
  - host: $5
    http:
      paths:
      - path: $6
        backend:
          serviceName: $2-nginx-svc
          servicePort: 80

EOF

        kubectl --kubeconfig /root/${9}.conf create -f k8s-dev-ingress/$5.yaml
        
      fi
  fi  

fi