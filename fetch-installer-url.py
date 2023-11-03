#!/usr/bin/python
# encoding: utf-8
#

# This is based on https://github.com/scriptingosx/fetch-installer-pkg 
# This version only gets the URLs and the versionnumbers of the Installers 
# and puts them on a website, so another script can get them. 
# Compatibility with Python 2 was removed.

# Copyright 2020 Armin Briegel.
#
# based on Greg Neagle's 'installinstallmacos.py'
# https://github.com/munki/macadmin-scripts/blob/main/installinstallmacos.py
#
# with many thanks to Greg Neagle for the original script and lots of advice
# and Mike Lynn for helping me figure out the software update catalog
# Graham R Pugh for figurung out the 11.1 download
# see his combined version of mine and Greg's script here:
# https://github.com/grahampugh/erase-install/tree/pkg

#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

'''fetch-full-installer.py
A tool to download the a pkg installer for the Install macOS app from Apple's
softwareupdate servers'''

import gzip
import os
import plistlib
import subprocess
import sys
from urllib.parse import urlsplit
from xml.dom import minidom
from xml.parsers.expat import ExpatError

MYCATALOG = 'https://swscan.apple.com/content/catalogs/others/index-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog'

def read_plist(filepath):
    with open(filepath, "rb") as fileobj:
        return plistlib.load(fileobj)

def read_plist_from_string(bytestring):
    return plistlib.loads(bytestring)

class ReplicationError(Exception):
    '''A custom error when replication fails'''
    pass


def replicate_url(full_url,
                  root_dir='/tmp',
                  show_progress=False,
                  ignore_cache=False,
                  attempt_resume=False):
    '''Downloads a URL and stores it in the same relative path on our
    filesystem. Returns a path to the replicated file.'''

    path = urlsplit(full_url)[2]
    relative_url = path.lstrip('/')
    relative_url = os.path.normpath(relative_url)
    local_file_path = os.path.join(root_dir, relative_url)
    if show_progress:
        options = '-fL'
    else:
        options = '-sfL'
    curl_cmd = ['/usr/bin/curl', options,
                '--create-dirs',
                '-o', local_file_path]
    if not full_url.endswith(".gz"):
        # stupid hack for stupid Apple behavior where it sometimes returns
        # compressed files even when not asked for
        curl_cmd.append('--compressed')
    if not ignore_cache and os.path.exists(local_file_path):
        curl_cmd.extend(['-z', local_file_path])
        if attempt_resume:
            curl_cmd.extend(['-C', '-'])
    curl_cmd.append(full_url)
    #print("Downloading %s..." % full_url)
    try:
        subprocess.check_call(curl_cmd)
    except subprocess.CalledProcessError as err:
        raise ReplicationError(err)
    return local_file_path


def parse_server_metadata(filename):
    '''Parses a softwareupdate server metadata file, looking for information
    of interest.
    Returns a dictionary containing title, version, and description.'''
    title = ''
    vers = ''
    try:
        md_plist = read_plist(filename)
    except (OSError, IOError, ExpatError) as err:
        print('Error reading %s: %s' % (filename, err), file=sys.stderr)
        return {}
    vers = md_plist.get('CFBundleShortVersionString', '')
    localization = md_plist.get('localization', {})
    preferred_localization = (localization.get('English') or
                              localization.get('en'))
    if preferred_localization:
        title = preferred_localization.get('title', '')

    metadata = {}
    metadata['title'] = title
    metadata['version'] = vers
    return metadata


def get_server_metadata(catalog, product_key):
    '''Replicate ServerMetaData'''
    try:
        url = catalog['Products'][product_key]['ServerMetadataURL']
        try:
            smd_path = replicate_url(
                url)
            return smd_path
        except ReplicationError as err:
            print('Could not replicate %s: %s' % (url, err), file=sys.stderr)
            return None
    except KeyError:
        #print('Malformed catalog.', file=sys.stderr)
        return None


def parse_dist(filename):
    '''Parses a softwareupdate dist file, returning a dict of info of
    interest'''
    dist_info = {}
    try:
        dom = minidom.parse(filename)
    except ExpatError:
        print('Invalid XML in %s' % filename, file=sys.stderr)
        return dist_info
    except IOError as err:
        print('Error reading %s: %s' % (filename, err), file=sys.stderr)
        return dist_info

    titles = dom.getElementsByTagName('title')
    if titles:
        dist_info['title_from_dist'] = titles[0].firstChild.wholeText

    auxinfos = dom.getElementsByTagName('auxinfo')
    if not auxinfos:
        return dist_info
    auxinfo = auxinfos[0]
    key = None
    value = None
    children = auxinfo.childNodes
    # handle the possibility that keys from auxinfo may be nested
    # within a 'dict' element
    dict_nodes = [n for n in auxinfo.childNodes
                  if n.nodeType == n.ELEMENT_NODE and
                  n.tagName == 'dict']
    if dict_nodes:
        children = dict_nodes[0].childNodes
    for node in children:
        if node.nodeType == node.ELEMENT_NODE and node.tagName == 'key':
            key = node.firstChild.wholeText
        if node.nodeType == node.ELEMENT_NODE and node.tagName == 'string':
            value = node.firstChild.wholeText
        if key and value:
            dist_info[key] = value
            key = None
            value = None
    return dist_info


def download_and_parse_sucatalog(sucatalog):
    '''Downloads and returns a parsed softwareupdate catalog'''
    try:
        localcatalogpath = replicate_url(
            sucatalog)
    except ReplicationError as err:
        print('Could not replicate %s: %s' % (sucatalog, err), file=sys.stderr)
        exit(-1)
    if os.path.splitext(localcatalogpath)[1] == '.gz':
        with gzip.open(localcatalogpath) as the_file:
            content = the_file.read()
            try:
                catalog = read_plist_from_string(content)
                return catalog
            except ExpatError as err:
                print('Error reading %s: %s' % (localcatalogpath, err),
                      file=sys.stderr)
                exit(-1)
    else:
        try:
            catalog = read_plist(localcatalogpath)
            return catalog
        except (OSError, IOError, ExpatError) as err:
            print('Error reading %s: %s' % (localcatalogpath, err),
                  file=sys.stderr)
            exit(-1)


def find_mac_os_installers(catalog, installassistant_pkg_only=False):
    '''Return a list of product identifiers for what appear to be macOS
    installers'''
    mac_os_installer_products = []
    if 'Products' in catalog:
        for product_key in catalog['Products'].keys():
            product = catalog['Products'][product_key]
            try:
                if product['ExtendedMetaInfo']['InstallAssistantPackageIdentifiers']:
                    if product['ExtendedMetaInfo']['InstallAssistantPackageIdentifiers'
                        ]['SharedSupport']:
                        mac_os_installer_products.append(product_key)
            except KeyError:
                continue
    return mac_os_installer_products

def os_installer_product_info(catalog):
    '''Returns a dict of info about products that look like macOS installers'''
    product_info = {}
    installer_products = find_mac_os_installers(catalog)
    for product_key in installer_products:
        product_info[product_key] = {}
        filename = get_server_metadata(catalog, product_key)
        if filename:
            product_info[product_key] = parse_server_metadata(filename)
        else:
            #print('No server metadata for %s' % product_key)
            product_info[product_key]['title'] = None
            product_info[product_key]['version'] = None

        product = catalog['Products'][product_key]
        product_info[product_key]['PostDate'] = product['PostDate']
        distributions = product['Distributions']
        dist_url = distributions.get('English') or distributions.get('en')
        try:
            dist_path = replicate_url(
                dist_url, show_progress=False)
        except ReplicationError as err:
            print('Could not replicate %s: %s' % (dist_url, err),
                  file=sys.stderr)
        else:
            dist_info = parse_dist(dist_path)
            product_info[product_key]['DistributionPath'] = dist_path
            product_info[product_key].update(dist_info)
            if not product_info[product_key]['title']:
                product_info[product_key]['title'] = dist_info.get('title_from_dist')
            if not product_info[product_key]['version']:
                product_info[product_key]['version'] = dist_info.get('VERSION')
        
    return product_info


def replicate_product(catalog, product_id):
    '''Downloads all the packages for a product'''
    product = catalog['Products'][product_id]
    for package in product.get('Packages', []):
        # TO-DO: Check 'Size' attribute and make sure
        # we have enough space on the target
        # filesystem before attempting to download
        if 'URL' in package:
            try:
                replicate_url(
                    package['URL'],
                    show_progress=True,
                    attempt_resume=())
            except ReplicationError as err:
                print('Could not replicate %s: %s' % (package['URL'], err),
                      file=sys.stderr)
                exit(-1)
        if 'MetadataURL' in package:
            try:
                replicate_url(package['MetadataURL'])
            except ReplicationError as err:
                print('Could not replicate %s: %s'
                      % (package['MetadataURL'], err), file=sys.stderr)
                exit(-1)

def main():
    '''Do the main thing here'''

    su_catalog_url = MYCATALOG
    if not su_catalog_url:
        print('Could not find a default catalog url for this OS version.',
              file=sys.stderr)
        exit(-1)

    # download sucatalog and look for products that are for macOS installers
    catalog = download_and_parse_sucatalog(su_catalog_url)
    
    # print(catalog)
    product_info = os_installer_product_info(catalog)

    if not product_info:
        print('No macOS installer products found in the sucatalog.',
              file=sys.stderr)
        exit(-1)

    # for schleife die alle Versionen abdeckt
    versiontitles = ["macOS Monterey", "macOS Ventura", "macOS Sonoma"]

    # Create a dictionary to map version titles to strings
    versiontitle_to_website = {
        "macOS Monterey": "/var/www/latest-monterey.example.com/index.html",
        "macOS Ventura": "/var/www/latest-ventura.example.com/index.html",
        "macOS Sonoma": "/var/www/latest-sonoma.example.com/index.html"
    }
    for x in versiontitles:
        # Filter products with the title "Ventura"
        filtered_product_info = {
            product_id: info
            for product_id, info in product_info.items()
            if info['title'] == x
        }

        if not filtered_product_info:
            print('No macOS installer products with the title "macOS Ventura" found in the sucatalog.',
                  file=sys.stderr)
            exit(-1)

        # Sort filtered products by release date in descending order
        sorted_product_info = sorted(filtered_product_info, key=lambda k: filtered_product_info[k]['PostDate'], reverse=True)

        # Take the latest version
        product_id = sorted_product_info[0]
        latest_product_info = filtered_product_info[product_id]

        # Determine the InstallAssistant pkg url
        for package in catalog['Products'][product_id]['Packages']:
            package_url = package['URL']
            if package_url.endswith('InstallAssistant.pkg'):
                break

        file_path = versiontitle_to_website.get(x)
        #print(file_path)
        with open(file_path, 'w') as file:
            file.write(latest_product_info.get('version', 'UNKNOWN') + '|' + package_url)

        #print("URL of InstallAssistant.pkg for the latest version: %s" % package_url)
        print(latest_product_info.get('version', 'UNKNOWN'),package_url)


if __name__ == '__main__':
    main()
