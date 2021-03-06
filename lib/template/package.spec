#
# spec file for "<%= name %>"
#
# Copyright (c) <%= Time.now.year %> <%= Etc.getlogin %>
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           <%= name %>
Version:        <%= version %>
Release:        1
License:        <%= license %>
Summary:        <%= summary %>
Url:            <%= url %>
Group:          Development/Libraries/Java
Source0:        %{name}.tar.xz
Source1:        build.sh
<% patches.to_enum.with_index.each do |patch, i| %>
Patch<%= i %>:         <%= patch %>
<% end %>
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  xz
BuildRequires:  java-devel
BuildRequires:  <%= kit_name %> == <%= kit_version %>
BuildArch:      noarch
Provides:       mvn(<%= group_id %>:<%= artifact_id %>) == <%= version %>
Requires:       java
<% runtime_dependency_ids.each do |dependency_id| %>
Requires:       mvn(<%= dependency_id[0] %>:<%= dependency_id[1] %>) <% if dependency_id[3] != nil %>==<%= dependency_id[3] %><% end %>
<% end %>

%description
<%=
  description
%>

%prep
%setup -q -n src
<% patches.to_enum.with_index.each do |patch, i| %>
%patch<%= i %> -p2
<% end %>
cp -f %{SOURCE1} .
cp -Rf %{_datadir}/tetra ../kit

%build
cd ..
sh src/build.sh

%install
export NO_BRP_CHECK_BYTECODE_VERSION=true
mkdir -p %{buildroot}%{_javadir}
<% outputs.each do |output| %>
cp -a <%= output %> %{buildroot}%{_javadir}/<%= File.basename(output) %>
<% end %>

%files
%defattr(-,root,root)
<% outputs.each do |output| %>
%{_javadir}/<%= File.basename(output) %>
<% end %>

%changelog
