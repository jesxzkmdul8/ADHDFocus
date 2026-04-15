Name:       ADHDFocus
Version:    0.1.0
Release:    1
Summary:    ADHD Focus Timer App

License:    GPLv3
Group:      Applications/Productivity

BuildRequires: pkgconfig(sailfishapp)
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: pkgconfig(Qt5Gui)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Multimedia)

Requires: qt5-qtdeclarative-import-settings
Requires: libkeepalive

%description
Focus timer app for ADHD users using structured time blocks.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
make %{?_smp_mflags}

%install
%qmake5_install

%files
%{_bindir}/ADHDFocus
%{_datadir}/%{name}/qml/*
%{_datadir}/%{name}/sounds/*
%{_datadir}/%{name}/translations/*
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
