#!/bin/bash

if [ $# -lt 7 ]; then
    echo "k8s-deploy command usage: ./k8s-deploy.sh imageLibrary appName replicas config-map storage expose_service domain_name context_path docker_tag probe_path kubeconfig ingress_scm_url"
    exit 1
fi



if kubectl --kubeconfig /root/${11}.conf get svc $2-svc| grep $2-svc > /dev/null; then

   kubectl --kubeconfig /root/${11}.conf  set image deployment/$2-deployment $2=registry.aegonthtf.com/$1/$2:$9

else

    cat << EOF > application.yaml
kind: Service
apiVersion: v1
metadata:
  name: $2-svc
spec:
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  selector:
      app: $2
  type: ClusterIP
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name:  $2-deployment
  namespace: default
  labels:
    app:  $2
spec:
  replicas: $3
  template:
    metadata:
      labels:
        app: $2
    spec:
      terminationGracePeriodSeconds: 35
      containers:
      - name: $2
        image: registry.aegonthtf.com/$1/$2:$9
        imagePullPolicy: Always
        readinessProbe:
          httpGet:
            path: ${10}
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 6
          successThreshold: 1
          failureThreshold: 5
        livenessProbe:  
          httpGet:
            path: ${10}
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 6
          successThreshold: 1
          failureThreshold: 5      
        ports:
          - name: http
            containerPort: 8080

EOF

  if [[ $4 != "default-tomcat-config" ]]
  then
      cat << EOF >> application.yaml
        env:
        - name: JDBC_RESOURCE_1
          valueFrom:
             configMapKeyRef:
               name: $4
               key: JDBC_RESOURCE_1
        - name: JDBC_RESOURCE_LINK_1
          valueFrom:
            configMapKeyRef:
              name: $4
              key: JDBC_RESOURCE_LINK_1 
EOF
  
  fi
  
  if [[ $5 == "true" ]]  
  then  
    cat << EOF >> application.yaml
        volumeMounts: 
              - 
                name: "nas-directory"
                mountPath: "/appdata"
      volumes: 
          - 
            name: "nas-directory"
            hostPath:
              path: "/appdata/"   
EOF
  
  fi
                    
  kubectl --kubeconfig /root/${11}.conf create -f application.yaml
  
  # 需要暴露Service
  if [[ $6 == "true" ]]
  then
           
      #git clone ${12}
            
  
      # 选定域名是否存在，若存在，则需要Append本项目的设置, 若不存在，则新建
      if kubectl --kubeconfig /root/${11}.conf get ingress $7 | grep $7 > /dev/null;
      then
      
          if ls k8s-dev-ingress/$7.yaml | grep $7 > /dev/null;
          then
               if grep -wq "$2-svc" k8s-dev-ingress/$7.yaml;
               then
                  echo ' ';
               else
                 cat << EOF >> k8s-dev-ingress/$7.yaml
      - path: $8
        backend:
          serviceName: $2-svc
          servicePort: 8080
EOF
                fi
          else
              echo 'No appropriat ingress yaml file exists, please check';
          fi
        
          kubectl --kubeconfig /root/${11}.conf replace -f k8s-dev-ingress/$7.yaml

      else

        
         cat << EOF > k8s-dev-ingress/$7.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: $7
spec:
  rules:
  - host: $7
    http:
      paths:
      - path: $8
        backend:
          serviceName: $2-svc
          servicePort: 8080

EOF

        kubectl --kubeconfig /root/${11}.conf create -f k8s-dev-ingress/$7.yaml
        
        #cd k8s-dev-ingress
        
        #git add .
        #git commit -m 'update ingress yaml'
        #git push origin master

      fi
  fi  
fi  
