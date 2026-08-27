'use strict';
'require view';
'require form';
'require fs';
'require ui';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('tgbot', _('Telegram Bot'),
			_('Настройки Telegram-бота управления роутером. После изменения настроек нажмите «Перезапустить бота».'));

		s = m.section(form.NamedSection, 'config', 'tgbot', _('Настройки'));
		s.addremove = false;

		o = s.option(form.Value, 'token', _('Bot Token'));
		o.password = true;
		o.rmempty = false;
		o.datatype = 'string';

		o = s.option(form.Value, 'chatid', _('Chat ID (ваш user ID в Telegram)'));
		o.rmempty = false;
		o.datatype = 'uinteger';

		o = s.option(form.ListValue, 'lang', _('Мова / Language / Язык'),
			_('Мова повідомлень бота / Bot message language / Язык сообщений бота'));
		o.value('ru', 'Русский');
		o.value('uk', 'Українська');
		o.value('en', 'English');
		o.default = 'uk';
		o.optional = true;


		o = s.option(form.Flag, 'watch_quiet', _('Тихий режим вотчера'),
			_('Не надсилати миттєві сповіщення про DHCP-аренди та порти (події лишаються в логу)'));
		o.default = o.disabled;
		o.optional = true;

		o = s.option(form.Button, '_restart');
		o.title = _('Перезапуск');
		o.inputtitle = _('🔄 Перезапустить бота');
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/etc/init.d/tg-bot', ['restart'])
				.then(function() {
					ui.addNotification(null, E('p', _('Бот перезапущен с новыми настройками')), 'info');
				})
				.catch(function(e) {
					ui.addNotification(null, E('p', _('Ошибка перезапуска: %s').format(e.message)), 'error');
				});
		};

		o = s.option(form.Button, '_restart_watch');
		o.title = _('Вотчер подій');
		o.inputtitle = _('🔄 Перезапустить tg-watch');
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/etc/init.d/tg-watch', ['restart'])
				.then(function() {
					ui.addNotification(null, E('p', _('tg-watch перезапущено')), 'info');
				})
				.catch(function(e) {
					ui.addNotification(null, E('p', _('Ошибка перезапуска: %s').format(e.message)), 'error');
				});
		};

		return m.render();
	}
});
