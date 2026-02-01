class QemuDeviceSdk < Formula
  desc "QEMU Device Module Development SDK"
  homepage "https://www.qemu.org"
  url "https://download.qemu.org/qemu-device-sdk-10.0.0.tar.gz"
  sha256 "YOUR_SHA256_HERE"
  license "GPL-2.0-only"

  depends_on "glib"
  depends_on "pkg-config" => :build

  def install
    # SDK is pre-built, just install files
    prefix.install Dir["*"]
    
    # Ensure include directory is in the right place
    include.install_symlink prefix/"include/qemu-device" => "qemu-device"
    
    # Ensure pkg-config can find the file
    (lib/"pkgconfig").install_symlink prefix/"lib/pkgconfig/qemu-device.pc"
  end

  test do
    # Test that pkg-config works
    system "pkg-config", "--exists", "qemu-device"
    system "pkg-config", "--cflags", "qemu-device"
    
    # Test that headers exist
    assert_predicate include/"qemu-device/qemu/module.h", :exist?
    assert_predicate include/"qemu-device/qom/object.h", :exist?
    assert_predicate include/"qemu-device/hw/core/qdev.h", :exist?
    
    # Test that config files exist
    assert_predicate include/"qemu-device/config/config-host.h", :exist?
  end
end
