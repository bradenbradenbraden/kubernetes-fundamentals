	kubectl apply -f ../configs/base/alertmanager.yaml
	kubectl apply -f ../configs/base/elastic-stack.yaml
	kubectl apply -f ../configs/base/fluentd-config.yaml
	kubectl apply -f ../configs/base/mongostack.yaml
	kubectl apply -f ../configs/base/services.yaml
	kubectl apply -f ../configs/base/storage.yaml
	kubectl apply -f ../configs/base/workloads.yaml
