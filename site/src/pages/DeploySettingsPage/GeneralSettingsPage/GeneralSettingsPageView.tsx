import Box from "@mui/material/Box";
import { ClibaseOption, DAUsResponse, Entitlements } from "api/typesGenerated";
import { ErrorAlert } from "components/Alert/ErrorAlert";
import {
  ActiveUserChart,
  ActiveUsersTitle,
} from "components/ActiveUserChart/ActiveUserChart";
import { Header } from "components/DeploySettingsLayout/Header";
import OptionsTable from "components/DeploySettingsLayout/OptionsTable";
import { Stack } from "components/Stack/Stack";
import { ChartSection } from "./ChartSection";
import { useDeploymentOptions } from "utils/deployOptions";
import { docs } from "utils/docs";

export type GeneralSettingsPageViewProps = {
  deploymentOptions: ClibaseOption[];
  deploymentDAUs?: DAUsResponse;
  deploymentDAUsError: unknown;
  entitlements: Entitlements | undefined;
};
export const GeneralSettingsPageView = ({
  deploymentOptions,
  deploymentDAUs,
  deploymentDAUsError,
  entitlements,
}: GeneralSettingsPageViewProps): JSX.Element => {
  return (
    <>
      <Header
        title="General"
        description="Information about your Coder deployment."
        docsHref={docs("/admin/configure")}
      />
      <Stack spacing={4}>
        {Boolean(deploymentDAUsError) && (
          <ErrorAlert error={deploymentDAUsError} />
        )}
        {deploymentDAUs && (
          <Box height={200} sx={{ mb: 3 }}>
            <ChartSection title={<ActiveUsersTitle />}>
              <ActiveUserChart
                data={deploymentDAUs.entries}
                interval="day"
                userLimit={
                  entitlements?.features.user_limit.enabled
                    ? entitlements?.features.user_limit.limit
                    : undefined
                }
              />
            </ChartSection>
          </Box>
        )}
        <OptionsTable
          options={useDeploymentOptions(
            deploymentOptions,
            "Access URL",
            "Wildcard Access URL",
            "Experiments",
          )}
        />
      </Stack>
    </>
  );
};
