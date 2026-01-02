module MessageTemplatesHelper
  def default_message_template_content
    <<~'HTML'
      <p style="color: #333; font-size: 16px; line-height: 1.5;">Здравствуйте, {{ client.name }}!</p>

      <p style="color: #333; font-size: 16px; line-height: 1.5;">Ваша заявка #{{ incase.display_number }} была обновлена.</p>

      <ul style="margin: 10px 0; padding-left: 20px;">
        <li style="margin: 5px 0; color: #555;">Статус: <strong style="color: #7c3aed;">{{ incase.status }}</strong></li>
        <li style="margin: 5px 0; color: #555;">Форма: <strong style="color: #7c3aed;">{{ webform.title }}</strong></li>
      </ul>

      <p style="color: #333; font-size: 16px; line-height: 1.5;">________________________</p>
      <p style="color: #333; font-size: 16px; line-height: 1.5;">С уважением, Ваш магазин</p>

    HTML
  end
end

