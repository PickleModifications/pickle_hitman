import cx from 'clsx';
import { useEffect, useState } from 'react';
import { Group, Container, Table, ScrollArea, useMantineTheme, TableData, Text } from '@mantine/core';
import { Search } from '../search/Search';
import classes from './TableScrollArea.module.css';
import { IconChevronCompactDown, IconChevronDown, IconChevronUp, IconRefresh } from '@tabler/icons-react';
import { useConfig } from '../../providers/config/Config';

function parseLocaleNumber(val: string, locale: string) {
  return Number(val.replace(/[^0-9.-]/g, ''));
}

export function TableScrollArea({data, headerSizes, defaultSort, options} : {data: TableData, headerSizes?: any[], defaultSort?: {column: number, descending: boolean}, options?: any}) {
  let theme = useMantineTheme();
  const { config } = useConfig();
  const [scrolled, setScrolled] = useState(false);
  const [sort, setSort] = useState(defaultSort || {column: 0, descending: true});
  const headers = data.head?.map((header, headerId) => (header != "" ? (
    <Table.Th maw={(headerSizes && headerSizes.length - 1 >= headerId) ? headerSizes[headerId] : null} className={classes.tableHeader} key={headerId} onClick={() => {
      if (sort.column == headerId) {
        setSort({column: headerId, descending: !sort.descending});
      }
      else {
        setSort({column: headerId, descending: true});
    }}}>
      <Group gap={0} justify='space-between'>
        <Text>{header}</Text>
        {
          (sort.column == headerId) ? (
            (sort.descending ? <IconChevronDown height={20}/> : <IconChevronUp height={20}/>)
          ) : null
        }
      </Group>
    </Table.Th>
    ) : (
      <Table.Th key={headerId}>
        <Group gap={0} justify='space-between'>
          <div style={{minWidth: 10}}></div>
        </Group>
      </Table.Th>
  )));
  const [search, setSearch] = useState("");
  const [rowEntries, setRows] = useState(data.body || []);
  useEffect(() => {
    if (!data.body) return;
    if (search != "") {
      setRows(data.body.filter((row) => row.some((cell) => (cell ? cell : <></>).toString().toLowerCase().includes(search.toLowerCase()))));
    }
    else {
      setRows(data.body);
    }
  }, [data.body]);
  
  let rows = rowEntries.sort((a, b) => {
    let cellA = a[sort.column];
    let cellB = b[sort.column];
    if (cellA == null) {
      cellA = "";
    }
    if (cellB == null) {
      cellB = "";
    }
    if (cellA == cellB) {
      return 0;
    }
    const numberA = parseLocaleNumber(cellA.toString(), config.currency.locale);
    const numberB = parseLocaleNumber(cellB.toString(), config.currency.locale);
    if ((numberA != 0 && numberB != 0) && !isNaN(numberA) && !isNaN(numberB)) {
      if (sort.descending) {
        return numberA < numberB ? -1 : 1;
      }
      else {
        return numberA > numberB ? -1 : 1;
      }
    }
    else {
      if (sort.descending) {
        return cellA < cellB ? -1 : 1;
      }
      else {
        return cellA > cellB ? -1 : 1;
      }
    }
  }).map((row, rowId) => (
    <Table.Tr key={rowId}>
      {row.map((cell, cellId) => {
        let header = data.head?.[cellId];
        if (header && header != "") {
          return (
            <Table.Td style={{textOverflow: 'ellipsis', overflow: 'hidden', textWrap:"nowrap" }} key={cellId}>{cell}</Table.Td>
          );
        }
        else {
          return (
            <Table.Td style={{textOverflow: 'ellipsis', overflow: 'hidden', textWrap:"nowrap", width: 0}} key={cellId}>{cell}</Table.Td>
          );
        }
      })}
    </Table.Tr>
  ));

  return (
    <Container p={0} m={0} style={{rowGap:10, display: "flex", flexDirection:"column", flexGrow: 1, width: "100%"}}>
      <Group justify='space-between'>
        <Group>
          <Text fw={600} p={0} style={{flexGrow: 1}}>{data.caption}</Text>
          {
            ((rows && rows.length > 0) ? (<Text size='sm' style={{color: theme.colors.dark[1]}}>Showing {rows.length} result{rows.length > 1 ? "s" : ""}</Text>) : null)
          }
        </Group>
        <Group>
          <Group>{options}</Group>
          <IconRefresh style={{cursor: "pointer"}} size={20} onClick={() => {
            if (!data.body) return;
            setRows(data.body);
            if (search != "") {
              setRows(data.body.filter((row) => row.some((cell) => (cell ? cell : <></>).toString().toLowerCase().includes(search.toLowerCase()))));
            }
            else {
              setRows(data.body);
            }
          }}/>
          <Search size='xs' w={200} onChange={(event) => {
            if (!data.body) return;
            setSearch(event.currentTarget.value.toLowerCase());
            setRows(data.body.filter((row) => row.some((cell) => (cell ? cell : <></>).toString().toLowerCase().includes(event.currentTarget.value.toLowerCase()))));
          }}/>
        </Group>
      </Group>
      <ScrollArea scrollbarSize={5} style={{borderRadius: 5}} onScrollPositionChange={({ y }) => setScrolled(y !== 0)}>
        <Table style={{backgroundColor: theme.colors.dark[6]}} stripedColor="dark.5" striped withColumnBorders stickyHeader withRowBorders={false}>
          <Table.Thead style={{backgroundColor: "rgba(18, 18, 18, 1)"}} className={cx(classes.header, { [classes.scrolled]: scrolled })}>
            <Table.Tr>{headers}</Table.Tr>
          </Table.Thead>
          <Table.Tbody>{(rows && rows.length > 0) ? rows : <Table.Tr><Table.Td colSpan={data.head?.length}>No results found.</Table.Td></Table.Tr>
          }</Table.Tbody>
        </Table>
      </ScrollArea>
    </Container>
  );
}