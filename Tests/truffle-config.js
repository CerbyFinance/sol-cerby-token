module.exports = {
  // contracts_directory: "../",
  contracts_build_directory: "./compiled",
  test_directory: "./test",

  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
    },
  },
};