project('pix', 'cpp', version: '4.0.5', meson_version: '>=1.12.0', default_options: ['cpp_std=c++17', 'buildtype=release'])
qt6 = import('qt6')
cpp_compiler = meson.get_compiler('cpp')
if cpp_compiler.get_id() == 'gcc' and cpp_compiler.has_argument('-Wno-sfinae-incomplete')
    add_project_arguments('-Wno-sfinae-incomplete', language: 'cpp')
endif
qt = dependency('qt6', version: '>=6.9', modules: ['Core', 'DBus', 'Gui', 'Qml', 'Quick', 'Positioning', 'Concurrent'])
kf6_core = dependency('KF6CoreAddons', version: '>=6.13')
kf6_i18n = declare_dependency(
    include_directories: include_directories(get_option('prefix') / 'include' / 'KF6' / 'KI18n'),
    dependencies: [cpp_compiler.find_library('KF6I18n'), cpp_compiler.find_library('KF6I18nQml')],
)
kf6_kio = declare_dependency(
    include_directories: include_directories(
        get_option('prefix') / 'include' / 'KF6' / 'KIO',
        get_option('prefix') / 'include' / 'KF6' / 'KIOCore',
        get_option('prefix') / 'include' / 'KF6' / 'KIOFileWidgets',
    ),
    dependencies: [cpp_compiler.find_library('KF6KIOCore'), cpp_compiler.find_library('KF6KIOFileWidgets')],
)
kf6_windowsystem = dependency('KF6WindowSystem', version: '>=6.13')
mauikit = dependency('MauiKit4', version: '>=4.0.5')
filebrowsing = dependency('MauiKitFileBrowsing4', version: '>=4.0.5')
imagetools = dependency('MauiKitImageTools4', version: '>=4.0.5')
cpp_args = []
if host_machine.cpu_family() == 'x86_64'
    cpp_args += ['-march=x86-64-v3']
endif
pix_version = configure_file(
    input: 'meson-content.in',
    output: 'pix_version.h',
    configuration: {'CONTENT': ('''#pragma once
#define PIX_VERSION_STRING "4.0.5"
#define GIT_BRANCH "Stable"
#define GIT_COMMIT_HASH "4.0.5"
''')}
)
pix_includes = include_directories('src')
dbus_cpp2xml = find_program('qdbuscpp2xml')
dbus_xml2cpp = find_program('qdbusxml2cpp')
dbus_xml = custom_target('pix-dbus-xml', input: 'src/pixserver.h', output: 'org.kde.Pix.xml', command: [dbus_cpp2xml, '-o', '@OUTPUT@', '@INPUT@'])
dbus_adaptor = custom_target('pix-dbus-adaptor', input: dbus_xml, output: ['pixadaptor.cpp', 'pixadaptor.h'], command: [dbus_xml2cpp, '-a', 'pixadaptor', '@INPUT@'])
dbus_interface = custom_target('pix-dbus-interface', input: dbus_xml, output: ['pixinterface.cpp', 'pixinterface.h'], command: [dbus_xml2cpp, '-p', 'pixinterface', '@INPUT@'])
pix_sources = ['src/main.cpp', 'src/pix.cpp', 'src/models/gallery/gallery.cpp', 'src/models/folders/folders.cpp', 'src/models/folders/placesmodel.cpp', 'src/models/tags/tagsmodel.cpp', 'src/models/cities/citiesmodel.cpp', 'src/pixserver.cpp']
qt_sources = qt6.preprocess(qresources: ['src/assets/imgs.qrc', 'src/qml.qrc'], moc_headers: ['src/pix.h', 'src/models/gallery/gallery.h', 'src/models/folders/folders.h', 'src/models/folders/placesmodel.h', 'src/models/tags/tagsmodel.h', 'src/models/cities/citiesmodel.h', 'src/pixserver.h', dbus_adaptor[1], dbus_interface[1]])
executable('pix', pix_sources + [dbus_adaptor, dbus_interface] + qt_sources + [pix_version], dependencies: [qt, kf6_core, kf6_i18n, kf6_kio, kf6_windowsystem, mauikit, filebrowsing, imagetools], include_directories: pix_includes, cpp_args: cpp_args, install: true)
install_data('src/org.maui.pix.desktop', install_dir: get_option('datadir') / 'applications')
install_data('org.maui.pix.appdata.xml', install_dir: get_option('datadir') / 'metainfo')
install_data('src/assets/pix.svg', install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps')
