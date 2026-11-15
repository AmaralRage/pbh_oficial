package com.amaralstudios.pbh.conversations;

import android.app.Person;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ShortcutInfo;
import android.content.pm.ShortcutManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.drawable.Icon;
import android.os.Build;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

/** Registered by every Flutter engine, including Firebase's background engine. */
public final class ConversationPlugin implements FlutterPlugin {
    private MethodChannel channel;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "pbh/conversations");
        channel.setMethodCallHandler((call, result) -> {
            try {
                ShortcutManager manager = context.getSystemService(ShortcutManager.class);
                if (Build.VERSION.SDK_INT < 30 || manager == null) {
                    result.success(false);
                } else if (call.method.equals("clear")) {
                    android.content.SharedPreferences prefs = context.getSharedPreferences("pbh_conversations", 0);
                    java.util.List<String> ids = new java.util.ArrayList<>(prefs.getStringSet("ids", java.util.Collections.emptySet()));
                    for (ShortcutInfo shortcut : manager.getDynamicShortcuts()) {
                        if (shortcut.getId().startsWith("pbh.chat.")) ids.add(shortcut.getId());
                    }
                    manager.removeDynamicShortcuts(ids);
                    manager.removeLongLivedShortcuts(ids);
                    prefs.edit().remove("ids").apply();
                    result.success(true);
                } else if (call.method.equals("publish")) {
                    String id = call.argument("id"), name = call.argument("name");
                    String sender = call.argument("sender"), payload = call.argument("payload");
                    byte[] avatar = call.argument("avatar");
                    Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
                    if (id == null || name == null || intent == null) { result.success(false); return; }
                    intent.setAction("SELECT_NOTIFICATION");
                    intent.putExtra("payload", payload);
                    Integer notificationId = call.argument("notificationId");
                    intent.putExtra("notificationId", notificationId == null ? 0 : notificationId);
                    Bitmap bitmap = avatar == null ? null : BitmapFactory.decodeByteArray(avatar, 0, avatar.length);
                    if (bitmap == null) {
                        bitmap = Bitmap.createBitmap(128, 128, Bitmap.Config.ARGB_8888);
                        Canvas canvas = new Canvas(bitmap);
                        canvas.drawColor(Color.rgb(45, 40, 52));
                        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
                        paint.setColor(Color.WHITE); paint.setTextSize(64); paint.setTextAlign(Paint.Align.CENTER);
                        canvas.drawText(name.isEmpty() ? "?" : name.substring(0, name.offsetByCodePoints(0, 1)).toUpperCase(), 64, 88, paint);
                    }
                    Icon icon = Icon.createWithAdaptiveBitmap(bitmap);
                    ShortcutInfo shortcut = new ShortcutInfo.Builder(context, id)
                        .setShortLabel(name.isEmpty() ? "Conversa" : name)
                        .setIntent(intent).setIcon(icon).setLongLived(true)
                        .setPersons(new Person[]{new Person.Builder().setName(name).setKey(sender).setIcon(icon).build()})
                        .build();
                    manager.pushDynamicShortcut(shortcut);
                    android.content.SharedPreferences prefs = context.getSharedPreferences("pbh_conversations", 0);
                    java.util.Set<String> ids = new java.util.HashSet<>(prefs.getStringSet("ids", java.util.Collections.emptySet()));
                    ids.add(id);
                    // Bound cached identities, including shortcuts evicted from the launcher.
                    while (ids.size() > 64) {
                        String obsolete = null;
                        for (String candidate : ids) if (!candidate.equals(id)) { obsolete = candidate; break; }
                        if (obsolete == null) break;
                        manager.removeDynamicShortcuts(java.util.Collections.singletonList(obsolete));
                        manager.removeLongLivedShortcuts(java.util.Collections.singletonList(obsolete));
                        ids.remove(obsolete);
                    }
                    prefs.edit().putStringSet("ids", ids).apply();
                    result.success(true);
                } else { result.notImplemented(); }
            } catch (Exception error) {
                // Shortcut limits or OEM restrictions must never prevent delivery.
                result.success(false);
            }
        });
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
