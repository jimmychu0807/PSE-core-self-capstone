"use client";

import { useLogContext } from "@/context/LogContext";
import { Container, HStack, Icon, IconButton, Link, Spinner, Stack, Text } from "@chakra-ui/react";
import { FaGithub } from "react-icons/fa";
import { useWalletInfo } from "@web3modal/wagmi/react";
import { projectInfo } from "@/config";

function PromptForWalletConnect() {
  return (
    <>
      <Text fontSize="xl" textAlign="center">
        Please connect with your wallet
      </Text>
    </>
  );
}

export default function PageContainer({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { log } = useLogContext();
  const { walletInfo } = useWalletInfo();

  return (
    <>
      <HStack align="center" justify="right" p="2">
        <Link href={projectInfo.github} isExternal>
          <IconButton
            aria-label="Github repository"
            variant="link"
            py="3"
            color="text.100"
            icon={<Icon boxSize={6} as={FaGithub} />}
          />
        </Link>
      </HStack>

      <Container maxW="xl" flex="1" display="flex" alignItems="center">
        <Stack pt="8" pb="24" display="flex" width="100%">
          {walletInfo ? <>{children}</> : <PromptForWalletConnect />}
        </Stack>
      </Container>

      {log && (
        <HStack
          flexBasis="56px"
          borderTopWidth="1px"
          borderTopColor="text.600"
          backgroundColor="darkBlueBg"
          align="center"
          justify="center"
          spacing="4"
          p="4"
        >
          {log.endsWith("...") && <Spinner color="primary.400" />}
          <Text>{log}</Text>
        </HStack>
      )}
    </>
  );
}
