#
# Cookbook Name:: kubernetes
# Recipe:: cleaner
#
# Author:: Maxim Filatov <bregor@evilmartians.com>
#

require 'fileutils'

%w(apiserver controller-manager scheduler proxy addon-manager).each do |srv|

  if node['kubernetes']['install_via'] == 'systemd'
    FileUtils.rm_f "/etc/kubernetes/manifests/#{srv}.yaml"
  end

  if node['kubernetes']['install_via'] == 'static_pods'
    systemd_service "kube-#{srv}" do
      action [:disable, :stop]
      only_if { node['init_package'] == 'systemd' }
    end
  end

  if node['kubernetes']['install_via'] == 'upstart'
    FileUtils.rm_f "/etc/kubernetes/manifests/#{srv}.yaml"
    systemd_service "kube-#{srv}" do
      action [:disable, :stop]
      only_if { node['init_package'] == 'systemd' }
    end
  end

end

# Cleanup old kubernetes binaries
versions = Dir["/opt/kubernetes/*"].sort_by {|f| File.mtime(f)}
FileUtils.rm_rf(versions[0...-node['kubernetes']['keep_versions']])

# Cleanup old skydns manifests
%w(kubedns-cm kubedns-sa skydns-deployment skydns-svc).each do |manifest|
  file "/etc/kubernetes/addons/#{manifest}.yaml" do
    action :delete
  end
end

# Cleanup DNS RBAC manifest when using kubedns
if node['kubernetes']['addons']['dns']['controller'] == 'kubedns'
  %w(clusterrole clusterrolebinding).each do |manifest|
    file "/etc/kubernetes/addons/dns-#{manifest}.yaml" do
      action :delete
    end
  end
end

# Cleanup static kubelet kubeconfig and keypair
file '/etc/kubernetes/kubelet_config.yaml' do
  action :delete
end

%w(crt key).each do |f|
  file "/etc/kubernetes/ssl/kubelet.#{f}" do
    action :delete
  end
end

# Kubelet clusterrolebinding
file '/etc/kubernetes/addons/kubelet-clusterrolebinding.yaml' do
  action :delete
end

# Delete weave-related resources when canal is used as SDN
if node['kubernetes']['sdn'] == 'canal'
  ['sa', 'clusterrole', 'clusterrolebinding', 'role', 'rolebinding', 'daemonset'].each do |addon|
    file "/etc/kubernetes/addons/weave-kube-#{addon}.yaml" do
      action :delete
    end
  end

  ['10-weave.conflist', '10-weave.conf'].each do |config|
    file "/etc/cni/net.d/#{config}.yaml" do
      action :delete
    end
  end
end

# Delete canal-related resources when weave is used as SDN
if node['kubernetes']['sdn'] == 'weave'
  %w(
  sa
  calico-clusterrole
  calico-clusterrolebinding
  flannel-clusterrole
  flannel-clusterrolebinding
  bgppeer-crd
  globalbgpconfigs-crd
  globalfelixconfigs-crd
  globalnetworkpolicies-crd
  ippools-crd
  configmap
  daemonset
  ).each do |addon|
    file "/etc/kubernetes/addons/canal-#{addon}.yaml" do
      action :delete
    end
  end

  ['10-calico.conflist', 'calico-kubeconfig'].each do |config|
    file "/etc/cni/net.d/#{config}.yaml" do
      action :delete
    end
  end
end

# Cleanup systemd-network kubernetes_services in case of proxy mode ipvs
if node['kubernetes']['proxy']['mode'] == 'ipvs'
  systemd_network 'kubernetes_services' do
    action :delete
  end
end
