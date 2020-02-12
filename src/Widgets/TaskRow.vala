/*
* Copyright 2019 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

public class Tasks.TaskRow : Gtk.ListBoxRow {
    public signal void task_save (ECal.Component task);
    public signal void task_delete (ECal.Component task);

    public bool completed { get; private set; }
    public E.Source source { get; construct; }
    public ECal.Component task { get; construct set; }

    private Granite.Widgets.DatePicker due_datepicker;
    private Granite.Widgets.TimePicker due_timepicker;

    private Gtk.CheckButton check;
    private Gtk.Entry summary_entry;
    private Gtk.Revealer task_form_revealer;
    private Gtk.Switch due_switch;
    private Gtk.TextBuffer description_textbuffer;

    private Tasks.TaskDetailRevealer task_detail_revealer;

    private static Gtk.CssProvider taskrow_provider;

    public TaskRow (E.Source source, ECal.Component task) {
        Object (source: source, task: task);
    }

    static construct {
        taskrow_provider = new Gtk.CssProvider ();
        taskrow_provider.load_from_resource ("io/elementary/tasks/TaskRow.css");
    }

    construct {
        check = new Gtk.CheckButton ();
        check.valign = Gtk.Align.CENTER;
        Tasks.Application.set_task_color (source, check);

        summary_entry = new Gtk.Entry ();

        unowned Gtk.StyleContext summary_entry_context = summary_entry.get_style_context ();
        summary_entry_context.add_class (Gtk.STYLE_CLASS_FLAT);
        summary_entry_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        task_detail_revealer = new Tasks.TaskDetailRevealer (task);
        task_detail_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;

        due_switch = new Gtk.Switch ();
        due_switch.valign = Gtk.Align.CENTER;

        var due_label = new Gtk.Label (_("Schedule:"));

        due_datepicker = new Granite.Widgets.DatePicker ();
        due_datepicker.hexpand = true;

        due_timepicker = new Granite.Widgets.TimePicker ();
        due_timepicker.hexpand = true;

        var description_textview = new Gtk.TextView ();
        description_textview.border_width = 12;
        description_textview.height_request = 140;
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
        description_textview.accepts_tab = false;

        description_textbuffer = new Gtk.TextBuffer (null);
        description_textview.set_buffer (description_textbuffer);

        var description_frame = new Gtk.Frame (null);
        description_frame.add (description_textview);

        var delete_button = new Gtk.Button ();
        delete_button.sensitive = false;
        delete_button.label = _("Delete Task");
        delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var cancel_button = new Gtk.Button ();
        cancel_button.label = _("Cancel");

        var save_button = new Gtk.Button ();
        save_button.label = _("Save Changes");
        save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        button_box.baseline_position = Gtk.BaselinePosition.CENTER;
        button_box.margin_top = 12;
        button_box.spacing = 6;
        button_box.set_layout (Gtk.ButtonBoxStyle.END);
        button_box.add (delete_button);
        button_box.set_child_secondary (delete_button, true);
        button_box.add (cancel_button);
        button_box.add (save_button);

        var form_grid = new Gtk.Grid ();
        form_grid.column_spacing = 12;
        form_grid.row_spacing = 12;
        form_grid.margin_bottom = 6;
        form_grid.attach (due_label, 0, 0);
        form_grid.attach (due_switch, 1, 0);
        form_grid.attach (due_datepicker, 2, 0);
        form_grid.attach (due_timepicker, 3, 0);
        form_grid.attach (description_frame, 0, 1, 4);
        form_grid.attach (button_box, 0, 2, 4);

        task_form_revealer = new Gtk.Revealer ();
        task_form_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        task_form_revealer.add (form_grid);

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = grid.margin_end = 12;
        grid.column_spacing = 6;
        grid.row_spacing = 3;
        grid.attach (check, 0, 0);
        grid.attach (summary_entry, 1, 0);
        grid.attach (task_detail_revealer, 1, 1);
        grid.attach (task_form_revealer, 1, 2);

        add (grid);
        margin_start = margin_end = 12;
        get_style_context ().add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        check.toggled.connect (() => {
            if (task == null) {
                return;
            }
            task.get_icalcomponent ().set_status (check.active ? ICal.PropertyStatus.COMPLETED : ICal.PropertyStatus.NONE);
            task_save (task);
        });

        summary_entry.activate.connect (() => {
            move_focus (Gtk.DirectionType.TAB_BACKWARD);
            save_task ();
        });

        summary_entry.grab_focus.connect (() => {
            reveal_child_request (true);
        });

        description_textview.button_press_event.connect (() => {
            description_textview.grab_focus ();
            return Gdk.EVENT_STOP;
        });

        cancel_button.clicked.connect (() => {
            cancel_edit ();
        });

        delete_button.clicked.connect (() => {
            task_delete (task);
        });

        key_release_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                cancel_edit ();
            }
        });

        save_button.clicked.connect (() => {
            save_task ();
        });

        notify["task"].connect (() => {
            task_detail_revealer.task = task;
            update_request ();
        });
        update_request ();

        due_switch.bind_property ("active", due_datepicker, "sensitive", GLib.BindingFlags.SYNC_CREATE);
        due_switch.bind_property ("active", due_timepicker, "sensitive", GLib.BindingFlags.SYNC_CREATE);
    }

    private void cancel_edit () {
        move_focus (Gtk.DirectionType.TAB_BACKWARD);
        summary_entry.text = task.get_icalcomponent ().get_summary ();
        reveal_child_request (false);
    }

    private void save_task () {
        unowned ICal.Component ical_task = task.get_icalcomponent ();

        if (due_switch.active) {
            ical_task.set_due (Util.date_time_to_ical (due_datepicker.date, due_timepicker.time));
            ical_task.set_due (Util.date_time_to_ical (due_datepicker.date, due_timepicker.time));
        } else {
            ical_task.set_due ( ICal.Time.null_time ());
        }

        // Clear the old description
        int count = ical_task.count_properties (ICal.PropertyKind.DESCRIPTION_PROPERTY);
        for (int i = 0; i < count; i++) {
#if E_CAL_2_0
            ICal.Property remove_prop;
#else
            unowned ICal.Property remove_prop;
#endif
            remove_prop = ical_task.get_first_property (ICal.PropertyKind.DESCRIPTION_PROPERTY);
            ical_task.remove_property (remove_prop);
        }

        // Add the new description - if we have any
        var description = description_textbuffer.text;
        if (description != null && description.strip ().length > 0) {
            var property = new ICal.Property (ICal.PropertyKind.DESCRIPTION_PROPERTY);
            property.set_description (description.strip ());
            ical_task.add_property (property);
        }

        task.get_icalcomponent ().set_summary (summary_entry.text);
        reveal_child_request (false);
        task_save (task);
    }

    public void reveal_child_request (bool value) {
        task_form_revealer.reveal_child = value;
        task_detail_revealer.reveal_child_request (!value);

        unowned Gtk.StyleContext style_context = get_style_context ();

        if (value) {
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class ("collapsed");
        } else {
            style_context.remove_class (Granite.STYLE_CLASS_CARD);
            style_context.remove_class ("collapsed");
        }
    }

    private void update_request () {
        if (task == null) {
            completed = false;
            check.active = completed;
            summary_entry.text = null;
            summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);

        } else {
            unowned ICal.Component ical_task = task.get_icalcomponent ();
            completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;
            check.active = completed;

            if (ical_task.get_due ().is_null_time ()) {
                due_switch.active = false;
                due_datepicker.date = due_timepicker.time = new DateTime.now_local ();
            } else {
                var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
                due_datepicker.date = due_timepicker.time = due_date_time;

                due_switch.active = true;
            }

            if (ical_task.get_description () != null) {
                description_textbuffer.text = ical_task.get_description ();
            } else {
                description_textbuffer.text = "";
            }

            summary_entry.text = ical_task.get_summary ();

            if (completed) {
                summary_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            } else {
                summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            }
        }
    }
}
