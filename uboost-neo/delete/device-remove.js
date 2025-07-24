(function() {
  // Данные для запроса
  const data = {
    userId: "3d6ppGkSbH",
    deviceId: "288b330a-b6ac-49b2-8847-7a5d857640a0"
  };

  // Выполняем POST-запрос
  fetch("https://uubb.website/api/v2/premium/deactivate-device", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(data)
  })
  .then(response => {
    // Можно обработать ответ, если нужно
    if (!response.ok) {
      console.error("Ошибка деактивации устройства");
    }
    return response.json();
  })
  .then(result => {
    // Можно что-то сделать с результатом
    console.log("Результат:", result);
  })
  .catch(error => {
    // Не ломаем страницу при ошибке
    console.error("Ошибка запроса:", error);
  });
})();