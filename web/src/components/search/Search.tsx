import { TextInput, TextInputProps, ActionIcon, useMantineTheme, rem } from '@mantine/core';
import { IconSearch, IconArrowRight } from '@tabler/icons-react';

export function Search(props: TextInputProps) {
  const theme = useMantineTheme();

  return (
    <TextInput
      radius={5}
      placeholder="Search"
      leftSection={<IconSearch size={20} stroke={1.5} />}

      {...props}
    />
  );
}