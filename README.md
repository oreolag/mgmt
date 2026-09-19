<p align="right">
<a href="https://oreol.ch">Oreol</a> <a href="https://github.com/oreolag/ansible-collection">Ansible Collection</a> <a href="https://github.com/oreolag/cli">CLI</a>
</p>

<!-- <p align="center" style="margin-bottom: 0px;">
  <img src="https://github.com/oreolag/cli/blob/2026.3/CLI_blue.svg" 
       align="center" style="width: 200px; height: auto;">
</p> -->

<h1 align="center">
  Oreol Management
  <p align="center">
    <a href="https://github.com/oreolag/mgmt/releases"><img src="https://img.shields.io/github/v/release/oreolag/mgmt" alt="Latest release" /></a>
    <a href="https://github.com/oreolag/mgmt/blob/main/LICENSE"><img src="https://img.shields.io/github/license/oreolag/mgmt" alt="License" /></a>
    <a href="https://github.com/oreolag/mgmt/graphs/contributors"><img src="https://img.shields.io/github/contributors/oreolag/mgmt?color=blue" alt="Contributors" /></a>
    <a href="https://github.com/oreolag/mgmt/stargazers"><img src="https://img.shields.io/github/stars/oreolag/mgmt?style=flat" alt="GitHub stars" /></a>
  </p>
</h1>

`mgmt` simplifies software installation and low-level system configuration across heterogeneous compute clusters and remote servers. Built on the [Oreol Ansible Collection,](https://github.com/oreolag/ansible-collection) it brings together your inventory, variables, and configuration management database (CMDB).

When [Oreol CLI](https://github.com/oreolag/cli) is installed on a remote server, `mgmt` can also be invoked directly through `odev`.

## Using mgmt

For Oreol-managed clusters, Oreol provides a customized repository for co-managing your infrastructure under your management agreement. For independently managed clusters and remote servers, follow the installation instructions below to get started.

## Installation
Run the following command on your Linux host (see [Supported Platforms](#supported-platforms)):

```bash
curl -H 'Cache-Control: no-cache' -fsSL https://oreol.ch/mgmt/install.sh | sudo bash
```

### Supported Platforms
`mgmt` currently supports Ubuntu-based Linux distributions. Validated environments include:

- Ubuntu
- NVIDIA DGX

Additional Linux distributions may work but are not officially validated yet.

### Verify the Installation

Verify your installation by running the test playbook on the local server:

```bash
cd /opt/mgmt && ./ansible-play.sh test local
```

## Updating Oreol Ansible Collection

Run the following command to upgrade [Oreol Ansible Collection](https://github.com/oreolag/ansible-collection) into the project's `collections` directory:

```bash
cd /opt/mgmt && sudo ./collections-update.sh
```

The default installation is owned by root, so updating it requires `sudo`.

## Examples

`ansible-play.sh` supports Tab completion for playbook names from [Oreol Ansible Collection](https://github.com/oreolag/ansible-collection) and inventory group names from `hosts`.

![](examples.gif)

## Citation

[![ACM](https://img.shields.io/badge/ACM-10.1145%2F3805700-green)](https://doi.org/10.1145/3805700)

If you use `mgmt` in your research, development, or publications, please cite the following reference:

```bibtex
@article{moya2026hacc,
  author    = {Javier Moya and Matthias Gabathuler and Mario Ruiz and Gustavo Alonso},
  title     = {A Development Platform for Managed Heterogeneous Accelerated Compute Clusters: A Case Study on ETH Zurich’s AMD HACC},
  journal   = {ACM Transactions on Reconfigurable Technology and Systems},
  year      = {2026},
  doi       = {10.1145/3805700},
  url       = {https://doi.org/10.1145/3805700}
}
```
