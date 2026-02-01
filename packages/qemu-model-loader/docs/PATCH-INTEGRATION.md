# QEMU Model Loader - CI/CD Integration Guide

Guide for integrating QEMU Model Loader patches into CI/CD pipelines.

## Table of Contents

1. [Overview](#overview)
2. [GitHub Actions](#github-actions)
3. [GitLab CI](#gitlab-ci)
4. [Jenkins](#jenkins)
5. [Travis CI](#travis-ci)
6. [Azure Pipelines](#azure-pipelines)
7. [Generic Integration](#generic-integration)
8. [Best Practices](#best-practices)

---

## Overview

### What to Test in CI/CD

1. **Patch Application** - Do patches apply cleanly?
2. **Build** - Does QEMU build with patches?
3. **SDK Installation** - Does SDK install correctly?
4. **Module Build** - Can example modules compile?
5. **Module Loading** - Do modules load in QEMU?

### CI/CD Workflow

```
┌─────────────┐
│ Checkout    │
│ Code        │
└──────┬──────┘
       │
┌──────▼──────┐
│ Install     │
│ Dependencies│
└──────┬──────┘
       │
┌──────▼──────┐
│ Apply       │
│ Patches     │
└──────┬──────┘
       │
┌──────▼──────┐
│ Build QEMU  │
│ + SDK       │
└──────┬──────┘
       │
┌──────▼──────┐
│ Test        │
│ Modules     │
└──────┬──────┘
       │
┌──────▼──────┐
│ Package &   │
│ Upload      │
└─────────────┘
```

---

## GitHub Actions

### Basic Workflow

`.github/workflows/qemu-sdk.yml`:

```yaml
name: QEMU SDK Build

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  test-patches:
    name: Test Patch Application
    runs-on: ubuntu-latest
    strategy:
      matrix:
        qemu-version: ['master', 'v9.2.0']
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y git
      
      - name: Test Patches
        run: |
          cd tests
          ./test-patch-apply.sh ${{ matrix.qemu-version }}

  build-sdk:
    name: Build QEMU with SDK
    runs-on: ubuntu-latest
    needs: test-patches
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Install Build Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \\
            build-essential meson ninja-build \\
            libglib2.0-dev pkg-config \\
            python3-pip python3-venv \\
            git
          pip3 install meson
      
      - name: Build QEMU with SDK
        run: |
          cd tests
          ./test-sdk-build.sh master
        timeout-minutes: 45
      
      - name: Upload SDK
        uses: actions/upload-artifact@v3
        with:
          name: qemu-device-sdk
          path: /tmp/*/install/include/qemu-device

  test-modules:
    name: Test Module Build and Load
    runs-on: ubuntu-latest
    needs: build-sdk
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \\
            libglib2.0-dev pkg-config \\
            qemu-system-arm qemu-system-x86
      
      - name: Download SDK
        uses: actions/download-artifact@v3
        with:
          name: qemu-device-sdk
          path: /tmp/sdk
      
      - name: Test Module Build
        run: |
          cd tests
          ./test-module-build.sh /tmp/sdk
      
      - name: Test Module Loading
        run: |
          cd tests
          ./test-module-load.sh ../examples
```

### Caching Dependencies

```yaml
- name: Cache QEMU Build
  uses: actions/cache@v3
  with:
    path: |
      ~/.cache/qemu-build
    key: ${{ runner.os }}-qemu-${{ hashFiles('patches/**') }}
    restore-keys: |
      ${{ runner.os }}-qemu-
```

### Matrix Build (Multiple Versions)

```yaml
jobs:
  test:
    strategy:
      matrix:
        qemu-version: ['v9.2.0', 'v10.0.0', 'master']
        os: ['ubuntu-latest', 'ubuntu-20.04']
    runs-on: ${{ matrix.os }}
    
    steps:
      - name: Test
        run: ./tests/run-all.sh ${{ matrix.qemu-version }}
```

---

## GitLab CI

### Basic Pipeline

`.gitlab-ci.yml`:

```yaml
stages:
  - test-patches
  - build
  - test-modules
  - package

variables:
  QEMU_VERSION: "master"
  GIT_DEPTH: "1"

# Test patch application
test:patches:
  stage: test-patches
  image: ubuntu:latest
  before_script:
    - apt-get update
    - apt-get install -y git
  script:
    - cd tests
    - ./test-patch-apply.sh $QEMU_VERSION
  only:
    - branches
    - merge_requests

# Build QEMU with SDK
build:sdk:
  stage: build
  image: ubuntu:latest
  before_script:
    - apt-get update
    - apt-get install -y build-essential meson ninja-build \\
        libglib2.0-dev pkg-config python3-pip git
    - pip3 install meson
  script:
    - cd tests
    - ./test-sdk-build.sh $QEMU_VERSION
  artifacts:
    paths:
      - /tmp/*/install/
    expire_in: 1 week
  timeout: 1h

# Test module building
test:modules:
  stage: test-modules
  image: ubuntu:latest
  dependencies:
    - build:sdk
  before_script:
    - apt-get update
    - apt-get install -y libglib2.0-dev pkg-config gcc
  script:
    - cd tests
    - ./test-module-build.sh /tmp/*/install/usr
  only:
    - branches

# Package SDK
package:sdk:
  stage: package
  image: ubuntu:latest
  dependencies:
    - build:sdk
  script:
    - cd sdk-package
    - ./create-sdk.sh --qemu-install /tmp/*/install/usr \\
        --output ../qemu-device-sdk.tar.gz
  artifacts:
    paths:
      - qemu-device-sdk.tar.gz
    expire_in: 30 days
  only:
    - main
    - tags
```

### Parallel Jobs

```yaml
test:patches:
  parallel:
    matrix:
      - QEMU_VERSION: ['v9.2.0', 'v10.0.0', 'master']
```

---

## Jenkins

### Jenkinsfile

```groovy
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'QEMU_VERSION',
            choices: ['master', 'v9.2.0', 'v10.0.0'],
            description: 'QEMU version to build'
        )
    }
    
    stages {
        stage('Setup') {
            steps {
                sh '''
                    sudo apt-get update
                    sudo apt-get install -y build-essential meson \\
                        ninja-build libglib2.0-dev pkg-config git
                '''
            }
        }
        
        stage('Test Patches') {
            steps {
                dir('tests') {
                    sh "./test-patch-apply.sh ${params.QEMU_VERSION}"
                }
            }
        }
        
        stage('Build SDK') {
            steps {
                timeout(time: 45, unit: 'MINUTES') {
                    dir('tests') {
                        sh "./test-sdk-build.sh ${params.QEMU_VERSION}"
                    }
                }
            }
        }
        
        stage('Test Modules') {
            steps {
                dir('tests') {
                    sh './test-module-build.sh /tmp/*/install/usr'
                }
            }
        }
        
        stage('Package') {
            when {
                branch 'main'
            }
            steps {
                dir('sdk-package') {
                    sh '''
                        ./create-sdk.sh --qemu-install /tmp/*/install/usr \\
                            --output ../qemu-device-sdk.tar.gz
                    '''
                }
                archiveArtifacts artifacts: 'qemu-device-sdk.tar.gz'
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Build successful!'
        }
        failure {
            echo 'Build failed!'
        }
    }
}
```

---

## Travis CI

### .travis.yml

```yaml
language: c
os: linux
dist: focal

env:
  matrix:
    - QEMU_VERSION=master
    - QEMU_VERSION=v9.2.0

install:
  - sudo apt-get update
  - sudo apt-get install -y build-essential meson ninja-build \\
      libglib2.0-dev pkg-config git qemu-system-arm

script:
  - cd tests
  - ./test-patch-apply.sh $QEMU_VERSION
  - ./test-sdk-build.sh $QEMU_VERSION
  - ./test-module-build.sh /tmp/*/install/usr
  - ./test-module-load.sh

cache:
  directories:
    - $HOME/.cache

notifications:
  email: false
```

---

## Azure Pipelines

### azure-pipelines.yml

```yaml
trigger:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  QEMU_VERSION: 'master'

stages:
  - stage: Test
    jobs:
      - job: TestPatches
        steps:
          - script: |
              sudo apt-get update
              sudo apt-get install -y git
            displayName: 'Install dependencies'
          
          - script: |
              cd tests
              ./test-patch-apply.sh $(QEMU_VERSION)
            displayName: 'Test patches'
  
  - stage: Build
    dependsOn: Test
    jobs:
      - job: BuildSDK
        timeoutInMinutes: 60
        steps:
          - script: |
              sudo apt-get update
              sudo apt-get install -y build-essential meson \\
                ninja-build libglib2.0-dev pkg-config git
            displayName: 'Install build dependencies'
          
          - script: |
              cd tests
              ./test-sdk-build.sh $(QEMU_VERSION)
            displayName: 'Build QEMU with SDK'
          
          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '/tmp/*/install'
              artifactName: 'qemu-sdk'
```

---

## Generic Integration

### For Any CI System

Basic shell script for integration:

```bash
#!/bin/bash
# ci-build.sh - Generic CI script

set -e

QEMU_VERSION="${QEMU_VERSION:-master}"
WORK_DIR=$(mktemp -d)

echo "=== Installing Dependencies ==="
# Adjust for your system
apt-get update
apt-get install -y build-essential meson ninja-build \\
    libglib2.0-dev pkg-config git

echo "=== Testing Patches ==="
cd tests
./test-patch-apply.sh "$QEMU_VERSION"

echo "=== Building SDK ==="
./test-sdk-build.sh "$QEMU_VERSION"

echo "=== Testing Modules ==="
./test-module-build.sh /tmp/*/install/usr
./test-module-load.sh

echo "=== Packaging ==="
cd ../sdk-package
./create-sdk.sh --qemu-install /tmp/*/install/usr \\
    --output /output/qemu-device-sdk.tar.gz

echo "=== Done ==="
```

Usage in CI:
```bash
QEMU_VERSION=master ./ci-build.sh
```

---

## Best Practices

### 1. Caching

Cache QEMU builds between runs:

```yaml
# GitHub Actions
- uses: actions/cache@v3
  with:
    path: ~/.cache/qemu
    key: qemu-${{ hashFiles('patches/**') }}

# GitLab
cache:
  key: qemu-build
  paths:
    - .cache/qemu/
```

### 2. Fail Fast

Test patches before expensive builds:

```yaml
stages:
  - quick-test    # Patch application (2 min)
  - build         # Full build (20-30 min)
  - test          # Module tests (5 min)
```

### 3. Parallel Execution

Test multiple versions in parallel:

```yaml
strategy:
  matrix:
    version: [v9.2.0, v10.0.0, master]
```

### 4. Timeouts

Set appropriate timeouts:

```yaml
timeout-minutes: 45  # QEMU build can take time
```

### 5. Artifacts

Save important outputs:

```yaml
artifacts:
  paths:
    - qemu-device-sdk.tar.gz
    - test-results/
```

### 6. Notifications

Alert on failures:

```yaml
on:
  failure:
    - send_email
    - post_to_slack
```

### 7. Scheduled Builds

Test regularly against QEMU master:

```yaml
schedule:
  - cron: '0 0 * * *'  # Daily at midnight
```

---

## Environment Variables

Customize behavior with environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `QEMU_VERSION` | `master` | QEMU version to test |
| `SKIP_SDK_BUILD` | `0` | Skip expensive SDK build |
| `SKIP_TESTS` | `0` | Skip module tests |
| `PARALLEL_JOBS` | `$(nproc)` | Number of parallel jobs |

Example:
```yaml
env:
  QEMU_VERSION: v9.2.0
  SKIP_SDK_BUILD: 0
  PARALLEL_JOBS: 4
```

---

## Troubleshooting CI

### Build Timeouts

**Problem**: CI times out during QEMU build

**Solutions**:
- Increase timeout: `timeout-minutes: 60`
- Use faster runners
- Cache QEMU builds
- Reduce target list: `--target-list=x86_64-softmmu`

### Insufficient Disk Space

**Problem**: No space left on device

**Solutions**:
- Clean before build: `docker system prune -af`
- Use shallow clones: `git clone --depth 1`
- Remove old artifacts

### Intermittent Failures

**Problem**: Tests pass locally but fail in CI

**Solutions**:
- Check exact CI environment
- Add more logging: `set -x`
- Test in Docker locally
- Check for timing issues

---

## Example: EDAPack/qemu-riscv

Complete example for EDAPack project:

```yaml
name: Build QEMU RISC-V with SDK

on:
  push:
    branches: [ main ]
  release:
    types: [ created ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Checkout qemu-model-loader
        uses: actions/checkout@v3
        with:
          repository: fvutils/qemu-model-loader
          path: qemu-model-loader
      
      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential meson ninja-build \\
            libglib2.0-dev pkg-config git
      
      - name: Clone QEMU
        run: git clone --depth 1 --branch v9.2.0 \\
          https://gitlab.com/qemu-project/qemu.git
      
      - name: Apply Patches
        run: |
          cd qemu
          git am ../qemu-model-loader/patches/v9.2/*.patch
      
      - name: Build QEMU
        run: |
          cd qemu
          ./configure --enable-modules \\
            --target-list=riscv32-softmmu,riscv64-softmmu \\
            --prefix=/usr
          make -j$(nproc)
      
      - name: Install
        run: |
          cd qemu
          make install DESTDIR=$PWD/install
          make install-dev-sdk DESTDIR=$PWD/install
      
      - name: Package SDK
        run: |
          cd qemu-model-loader/sdk-package
          ./create-sdk.sh --qemu-install ../../qemu/install/usr \\
            --output ../../qemu-riscv-sdk.tar.gz
      
      - name: Upload Release Assets
        if: github.event_name == 'release'
        uses: actions/upload-release-asset@v1
        with:
          upload_url: ${{ github.event.release.upload_url }}
          asset_path: ./qemu-riscv-sdk.tar.gz
          asset_name: qemu-riscv-sdk-${{ github.event.release.tag_name }}.tar.gz
          asset_content_type: application/gzip
```

---

## Summary

For CI/CD integration:

1. **Test patches first** (fast feedback)
2. **Build QEMU with SDK** (main build)
3. **Test modules** (validation)
4. **Package SDK** (artifacts)
5. **Upload/deploy** (distribution)

All major CI/CD systems supported with provided examples.
