class deploy_artifacts (
  $descriptor_file = $::descriptor_file,
  $component       = $::component,
  $path            = '/tmp/shinesolutions/aem-aws-stack-provisioner/',
) {

  # load descriptor file
  $descriptor_hash = loadjson("${path}/${descriptor_file}")
  notify { "The descriptor_hash is: ${descriptor_hash}": }

  # extract component hash
  $component_hash = $descriptor_hash[$component]
  notify { "The component_hash is: ${component_hash}": }

  if $component_hash {

    file { $path:
      ensure => directory,
      mode   => '0775',
    }

    # extract the assets hash
    $assets = $component_hash['assets']
    notify { "The assets is: ${assets}": }

    if $assets {

      file { "${path}/assets":
        ensure  => directory,
        mode    => '0775',
        require => File[$path],
      }

      $assets.each | Integer $index, Hash $asset| {

        # TODO: validate the asset values exist and populated

        archive { "${path}/assets/${asset[filename]}":
          ensure => present,
          source => $asset[source],
        } ->
          file { $asset[destination]:
            ensure => present,
            group  => $asset[group],
            owner  => $asset[owner],
            mode   => $asset[mode],
            source => "${path}/assets/${asset[filename]}",
          }

        if $asset[exec_command] and $asset[exec_command].strip.size > 0 {

          exec { $asset[exec_command]:
            require => File[$asset[destination]],
          }

        }

      }


    } else {

      notify { "no 'assets' defined for component: ${component} in descriptor file: ${descriptor_file}. nothing to deploy": }

    }

    # extract the packages hash
    $packages = $component_hash['packages']
    notify { "The packages is: ${packages}": }

    if $packages {

      # prepare the packages
      file { "${path}/packages":
        ensure  => directory,
        mode    => '0775',
        require => File[$path],
      }

      $packages.each | Integer $index, Hash $package| {

        # TODO: validate the package values exist and populated

        if !defined(File["${path}/packages/${package['group']}"]) {
          file { "${path}/packages/${package['group']}":
            ensure  => directory,
            mode    => '0775',
            require => File["${path}/packages"],
          }
        }

        archive { "${path}/packages/${package['group']}/${package['name']}-${package['version']}.zip":
          ensure  => present,
          source  => $package[source],
          require => File["${path}/packages/${package['group']}"],
          before  => Class['aem_resources::deploy_packages'],
        }

      }

      class { 'aem_resources::deploy_packages':
        packages => $packages,
        path     => "${path}/packages/",
      }

    } else {

      notify { "no 'packages' defined for component: ${component} in descriptor file: ${descriptor_file}. nothing to deploy": }

    }


  } else {

    notify { "component: ${component} not found in descriptor file: ${descriptor_file}. nothing to deploy": }

  }

}

include deploy_artifacts
