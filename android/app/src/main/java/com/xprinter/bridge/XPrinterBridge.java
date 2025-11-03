package com.xprinter.bridge;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.lang.reflect.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class XPrinterBridge implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
  private static final String TAG = "XPrinterBridge";
  private final Handler main = new Handler(Looper.getMainLooper());

  private MethodChannel channel;
  private Context context;
  private Activity activity;

  // reflection cache
  private String pkg;
  private Class<?> clsPOSConnect, clsIDeviceConnection, clsIConnectListener, clsPOSPrinter;

  private Object connection;  // IDeviceConnection
  private Object printer;     // POSPrinter

  @Override public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    context = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), "xprinter_sdk");
    channel.setMethodCallHandler(this);
  }
  @Override public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
    channel = null;
  }

  @Override public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
    try { tryInitSdk(); } catch (Throwable t) { Log.w(TAG, "Deferred init: " + t.getMessage()); }
  }
  @Override public void onDetachedFromActivity() { activity = null; }
  @Override public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) { onAttachedToActivity(binding); }
  @Override public void onDetachedFromActivityForConfigChanges() { }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "init":
        try { tryInitSdk(); result.success(true); }
        catch (Throwable t) { result.error("INIT_ERROR", t.getMessage(), null); }
        break;

      case "listUsb":
        listUsb(result);
        break;

      case "connectUsb": // {path: "..."} optional; auto-pick first if null/empty
        String path = call.argument("path");
        connectUsb(path, result);
        break;

      case "printText":
        String text = call.argument("text");
        printText(text == null ? "" : text, result);
        break;

      case "disconnect":
        disconnect();
        result.success(true);
        break;

      default:
        result.notImplemented();
    }
  }

  // ---------- SDK discovery ----------

  private void tryInitSdk() throws Exception {
    if (pkg != null) return;
    List<String> candidates = Arrays.asList("com.xprinter.sdk","com.xprinter.pos","com.xprinter.port");
    Throwable last = null;
    for (String p : candidates) {
      try {
        Class<?> posConnect = Class.forName(p + ".POSConnect");
        pkg = p;
        clsPOSConnect = posConnect;
        clsIDeviceConnection = Class.forName(p + ".IDeviceConnection");
        clsIConnectListener = Class.forName(p + ".IConnectListener");
        clsPOSPrinter = Class.forName(p + ".POSPrinter");
        clsPOSConnect.getMethod("init", Context.class).invoke(null, context);
        Log.i(TAG, "Detected XPrinter SDK: " + p);
        return;
      } catch (Throwable t) { last = t; }
    }
    throw new IllegalStateException("XPrinter SDK classes not found in AAR: " + (last==null?"unknown":last.getMessage()));
  }

  // ---------- Public ops ----------

  private void listUsb(MethodChannel.Result result) {
    main.post(() -> {
      try {
        tryInitSdk();
        // static List<String> getUsbDevices(Context)
        Method mGet = clsPOSConnect.getMethod("getUsbDevices", Context.class);
        @SuppressWarnings("unchecked")
        List<String> paths = (List<String>) mGet.invoke(null, context);
        if (paths == null) paths = new ArrayList<>();
        result.success(paths);
      } catch (Throwable t) {
        result.error("USB_LIST_ERROR", t.getMessage(), null);
      }
    });
  }

  private void connectUsb(String preferredPath, MethodChannel.Result result) {
    main.post(() -> {
      try {
        tryInitSdk();

        // enumerate paths
        Method mGet = clsPOSConnect.getMethod("getUsbDevices", Context.class);
        @SuppressWarnings("unchecked")
        List<String> paths = (List<String>) mGet.invoke(null, context);
        if (paths == null || paths.isEmpty()) {
          result.error("NO_USB", "No USB printer paths found. Ensure OTG host + permission.", null);
          return;
        }

        String path = (preferredPath != null && !preferredPath.trim().isEmpty())
                ? preferredPath.trim()
                : paths.get(0);

        // IDeviceConnection conn = POSConnect.createDevice(DEVICE_TYPE_USB)
        int DEVICE_TYPE_USB = clsPOSConnect.getDeclaredField("DEVICE_TYPE_USB").getInt(null);
        Method mCreate = clsPOSConnect.getMethod("createDevice", int.class);
        connection = mCreate.invoke(null, DEVICE_TYPE_USB);

        // listener
        Object listener = Proxy.newProxyInstance(
                clsIConnectListener.getClassLoader(),
                new Class[]{clsIConnectListener},
                (proxy, method, args) -> {
                  if ("onStatus".equals(method.getName()) && args != null && args.length >= 3) {
                    int code = (Integer) args[0];
                    String msg = String.valueOf(args[2]);
                    int CONNECT_SUCCESS = clsPOSConnect.getDeclaredField("CONNECT_SUCCESS").getInt(null);
                    int CONNECT_FAIL = clsPOSConnect.getDeclaredField("CONNECT_FAIL").getInt(null);
                    if (code == CONNECT_SUCCESS) {
                      try {
                        Constructor<?> ctor = clsPOSPrinter.getConstructor(clsIDeviceConnection);
                        printer = ctor.newInstance(connection);
                        postSuccess(result, true);
                      } catch (Throwable t) { postError(result, "PRINTER_INIT", t.getMessage()); }
                    } else if (code == CONNECT_FAIL) {
                      postError(result, "CONNECT_FAIL", msg);
                    }
                  }
                  return null;
                });

        // connectSync(String info=<USB path>, IConnectListener)
        Method mConnectSync = connection.getClass().getMethod("connectSync", String.class, clsIConnectListener);
        mConnectSync.invoke(connection, path, listener);

      } catch (Throwable t) {
        result.error("USB_CONNECT_ERROR", t.getMessage(), null);
      }
    });
  }

  private void printText(String text, MethodChannel.Result result) {
    main.post(() -> {
      try {
        if (printer == null) { postError(result, "NO_PRINTER", "Not connected"); return; }
        printer.getClass().getMethod("initializePrinter").invoke(printer);
        printer.getClass().getMethod("printString", String.class).invoke(printer, text + "\n");
        printer.getClass().getMethod("feedLine", int.class).invoke(printer, 3);
        printer.getClass().getMethod("cutPaper").invoke(printer);
        postSuccess(result, true);
      } catch (Throwable t) {
        result.error("PRINT_ERROR", t.getMessage(), null);
      }
    });
  }

  private void disconnect() {
    try {
      if (connection != null) {
        connection.getClass().getMethod("close").invoke(connection);
        connection = null;
      }
      printer = null;
    } catch (Throwable ignored) {}
  }

  private void postSuccess(MethodChannel.Result res, Object v) { main.post(() -> { try { res.success(v); } catch (Throwable ignored) {} }); }
  private void postError(MethodChannel.Result res, String code, String msg) { main.post(() -> { try { res.error(code, msg, null); } catch (Throwable ignored) {} }); }
}
