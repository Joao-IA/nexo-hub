// Spike S4 — can a GNOME Shell 50 extension publish the focused app over D-Bus?
// Throwaway code: see docs/spikes.md. Publishes only the .desktop id and the
// window class (never titles or contents).
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const BUS_NAME = 'io.github.joao_ia.NexoHub.Focus';
const OBJECT_PATH = '/io/github/joao_ia/NexoHub/Focus';
const IFACE_XML = `
<node>
  <interface name="io.github.joao_ia.NexoHub.Focus">
    <method name="GetFocused">
      <arg type="s" direction="out" name="appId"/>
      <arg type="s" direction="out" name="wmClass"/>
    </method>
    <signal name="FocusChanged">
      <arg type="s" name="appId"/>
      <arg type="s" name="wmClass"/>
    </signal>
  </interface>
</node>`;

export default class NexoFocusSpike extends Extension {
    enable() {
        this._tracker = Shell.WindowTracker.get_default();
        this._exported = Gio.DBusExportedObject.wrapJSObject(IFACE_XML, this);
        this._exported.export(Gio.DBus.session, OBJECT_PATH);
        this._ownerId = Gio.bus_own_name(
            Gio.BusType.SESSION, BUS_NAME, Gio.BusNameOwnerFlags.NONE,
            null, null, null);
        this._focusId = global.display.connect('notify::focus-window',
            () => this._emitFocus());
        this._emitFocus();
    }

    disable() {
        global.display.disconnect(this._focusId);
        Gio.bus_unown_name(this._ownerId);
        this._exported.unexport();
        this._exported = null;
        this._tracker = null;
    }

    // D-Bus method: returns [appId, wmClass].
    GetFocused() {
        return this._currentFocus();
    }

    _currentFocus() {
        const win = global.display.focus_window;
        if (!win)
            return ['', ''];
        const app = this._tracker.get_window_app(win);
        return [app?.get_id() ?? '', win.get_wm_class() ?? ''];
    }

    _emitFocus() {
        const [appId, wmClass] = this._currentFocus();
        console.debug(`[nexo-focus] focus app=${appId} class=${wmClass}`);
        this._exported.emit_signal('FocusChanged',
            new GLib.Variant('(ss)', [appId, wmClass]));
    }
}
