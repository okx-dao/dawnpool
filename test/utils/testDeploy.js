const { deployContracts } = require('./deployContracts');

deployContracts()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
