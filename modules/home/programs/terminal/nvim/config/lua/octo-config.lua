require("octo").setup()

-- Create KeyMaps
vim.keymap.set("n", "<leader>rs", "<cmd>Octo review start<cr>")
vim.keymap.set("n", "<leader>rd", "<cmd>Octo review discard<cr>")
vim.keymap.set("n", "<leader>rr", "<cmd>Octo review resume<cr>")
vim.keymap.set("n", "<leader>re", "<cmd>Octo review submit<cr>")
vim.keymap.set("n", "<leader>rca", "<cmd>Octo review comments<cr>")
vim.keymap.set("n", "<leader>rcs", "<cmd>Octo comment suggest<cr>")
vim.keymap.set("n", "<leader>rcc", "<cmd>Octo comment add<cr>")
vim.keymap.set("n", "<leader>rcr", "<cmd>Octo comment reply<cr>")
vim.keymap.set("n", "<leader>pd", "<cmd>Octo pr diff<cr>")
vim.keymap.set("n", "<leader>pc", "<cmd>Octo pr changes<cr>")
